/*
 * Copyright (c) 2012 Alessandro Ludovici, Pol Moreno, Xavi Gimemo 
 *	Universitat Politecnica de Catalunya (UPC)
 * All rights reserved
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are
 * met:
 *
 *     * Redistributions of source code must retain the above copyright
 *       notice, this list of conditions and the following disclaimer.
 *     * Redistributions in binary form must reproduce the above
 *       copyright notice, this list of conditions and the following
 *       disclaimer in the documentation and/or other materials provided
 *       with the distribution.
 *     * The name of the author may not be used to endorse or promote
 *       products derived from this software without specific prior
 *       written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 * "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 * LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
 * A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
 * OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 * SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
 * LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 * THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 * OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */
#include <IPDispatch.h>
#include <lib6lowpan.h>
#include <stdio.h>
#include </usr/msp430/include/math.h> 
#include "./include/coap_pdu.h"
#include "./include/coap_option.h"
#include "./include/coap_general.h"
#include "./include/coap_list.h"


module CoapClientP {
    provides interface CoapClient;
    uses {
        interface Boot;
        interface SplitControl as RadioControl;
        interface UDP as UdpClient;
        interface CoapPdu;
        interface Timer<TMilli> as Timers[uint8_t num];
        interface Queue<coap_pdu_t *> as IncomingQueue;
        interface Pool<coap_connection_t> as CoapConnectionPool;
        interface CoapList as WaitingList;
        interface Random;
        interface Leds;
    }
} implementation {
    uint8_t buffer[MAX_PACKET_LEN], idc = 0;
    uint16_t buffer_len;
    double random_factor = 1.5; /* ACK_RANDOM_FACTOR */
    coap_list_t waiting_list;	/* List of PDU waiting for an ACK */
    int wait_separate = 0; /* Flag to indicate if we wait a separate response */
 

    task void processIncomingTask();

	static error_t send(coap_pdu_t *pdu) {
        /* Write the packet and pass it to UDP*/
        if (call CoapPdu.packetWrite(pdu, buffer, &buffer_len) == SUCCESS){
          	if (call UdpClient.sendto(&pdu->addr, buffer, buffer_len) == SUCCESS)
          		return SUCCESS;     
        }
        return FAIL;
    }

    command void CoapClient.sendRequest(coap_pdu_t *request) {
    	coap_connection_t *conn = NULL;
		
		if (request->hdr.type == COAP_MESSAGE_CON) {
       		/* Keep until we receive the Ack or the number of re-tx expires */
            if ((conn = call CoapConnectionPool.get()) == NULL) { 
				/* Send a NON instead */
				request->hdr.type = COAP_MESSAGE_NON;
                goto send_message;
            }			
			/* Insert connection in the waiting list */
			conn->pdu = request;
			conn->nretransmit = 0;
			conn->is_separate_response = 0;
			conn->uri_id = 0;
			conn->is_observe = 0;
			/* Set the rtx timer*/
			conn->rtx_timer = COAP_DEFAULT_ACK_TIMEOUT * random_factor;
			idc += 1;
			/* If we could not store a CON msg then we could not start the RTX algorithm 
			*  Send a NON instead.
			*/
			if ((call WaitingList.insertListNode(&waiting_list, idc , conn) == FAIL)
				|| idc >= WAITING_LIST) {
				call CoapConnectionPool.put(conn);
                /* Send a NON */
                request->hdr.type = COAP_MESSAGE_NON;
                idc -= 1;
                goto send_message;
            }
            goto send_message;            	
         }

	send_message:
		if (send(request) == SUCCESS){
		 	if (request->hdr.type == COAP_MESSAGE_CON)
				call Timers.startOneShot[idc](conn->rtx_timer);
			else 
				call CoapPdu.delete(request);
		} else {
			if (request->hdr.type == COAP_MESSAGE_CON)
				idc -= 1;
			call CoapPdu.delete(request);
		} 		
    }


    event void Boot.booted() {
        call RadioControl.start();
        call WaitingList.initList(&waiting_list);
    }

    event void RadioControl.startDone(error_t e) {}

    event void RadioControl.stopDone(error_t e) {}
    

    /* The RTX Timer has Expired*/
    event void Timers.fired[uint8_t num](){
    	coap_connection_t *sconn;
		
		call WaitingList.getListNode(&waiting_list, num, (void **)&sconn);
		if (sconn->nretransmit < COAP_DEFAULT_MAX_RETRANSMIT) {
			/* RTX */;
			send(sconn->pdu);
			sconn->nretransmit++;
			sconn->rtx_timer = 2 * sconn->rtx_timer;
			call Timers.startOneShot[num](sconn->rtx_timer);
		} else {
		    /* We reach the max number of RTX */
		    call WaitingList.deleteListNode(&waiting_list, num, NULL);
			call CoapPdu.delete(sconn->pdu);
			signal CoapClient.failedtx();				
		}
    }

    /*
	* Received a new packet. Add to the processing list and launch a
	* Process task.
	*/
    event void UdpClient.recvfrom(struct sockaddr_in6 *from, void *data, 
                           uint16_t len, struct ip_metadata *meta) {

        coap_pdu_t *pdu;
		
        if ((pdu = call CoapPdu.create()) == NULL) {
            call CoapPdu.delete(pdu);
            return;
        }

        if (call CoapPdu.packetRead((uint8_t *)data, len, pdu) == FAIL) {  
			call CoapPdu.delete(pdu);
            return;
        }

        pdu->addr = *from;

        /* Enqueue new request */
        if ((call IncomingQueue.enqueue(pdu)) == FAIL) {  
            call CoapPdu.delete(pdu);
            return;
        }
   
        post processIncomingTask();

    }

    task void processIncomingTask() {
        coap_option_t *token, *token_conn = NULL;
        coap_pdu_t *response;
        coap_list_index_t *li;        
        coap_connection_t *request_conn;
        uint16_t key;
               		           
        if (call IncomingQueue.empty()) {    
           return;
        }
        
        response = call IncomingQueue.dequeue();           
        /* Get response token and try to match any sent request. */   
        switch (response->hdr.type) {
        	case COAP_MESSAGE_NON:
				signal CoapClient.messageReceived(response);
				goto clean_response;
				break;
			case COAP_MESSAGE_CON:
                if (wait_separate == 1){
                	/* Check if it is a separate response */
                	for (li = call WaitingList.first(&waiting_list);li;li = call WaitingList.next(li)) {
		   				call WaitingList.this(li, &key, (void **)&request_conn);
		   		 		if(request_conn->is_separate_response){
		   		 			if ((call CoapPdu.getOption(response, COAP_OPTION_TOKEN, &token) == SUCCESS)
 				      		&& (call CoapPdu.getOption(request_conn->pdu, COAP_OPTION_TOKEN, &token_conn)== SUCCESS)) {								
								if (strcmp(token->value, token_conn->value) == 0) {
									/* Remove from list */
									call WaitingList.deleteListNode(&waiting_list,key,NULL);
									call CoapPdu.delete(request_conn->pdu);
                           			call CoapConnectionPool.put(request_conn);
                           			wait_separate = 0;									
								} else {
									goto clean_response;
								}
		   		 			}		   		 		
                		}
                	}
                }
                signal CoapClient.messageReceived(response);
                goto clean_response;			             						
               	break;
               case COAP_MESSAGE_ACK:
	  		  		for (li = call WaitingList.first(&waiting_list);li;li = call WaitingList.next(li)) {
		   		 		call WaitingList.this(li, &key, (void **)&request_conn);		   		 		
		   		 		/* Mark as separate response if code = 0 */
		   		 		if(response->hdr.code == 0){
		   		 			request_conn->is_separate_response = 1;
		   		 			idc -= 1;
							call Timers.stop[key]();
		   		 			wait_separate = 1;
		   		 			goto clean_response;
		   		 		}		   		 		
		   		 		/* Check The Message ID*/	   		 		
                        if (response->hdr.id == request_conn->pdu->hdr.id) {
                        	/* If the Token option is present it MUST be the same of the request */
 				      		if ((call CoapPdu.getOption(response, COAP_OPTION_TOKEN, &token) == SUCCESS)
 				      		&& (call CoapPdu.getOption(request_conn->pdu, COAP_OPTION_TOKEN, &token_conn)== SUCCESS)) {								
								if (strcmp(token->value, token_conn->value) != 0) {
									/* Token is Wrong send and RST */
									response->hdr.type = COAP_MESSAGE_RST;
									response->hdr.code = 0;
									response->payload_len = 0;
									send(response);
        							goto clean_list;
								}
							}
							signal CoapClient.messageReceived(response);
							goto clean_list;
						 } else {
							/* Id is wrong */
							response->hdr.type = COAP_MESSAGE_RST;
							response->hdr.code = 0;
							response->payload_len = 0;
							send(response);
							goto clean_list;
						}
                     }
                 	break;
                 case COAP_MESSAGE_RST:
                 	signal CoapClient.messageReceived(response);
                 	break;
                 default:
                 	break;
                }
	clean_list:
       	idc -= 1;
	   	call Timers.stop[key]();  								
	   	call WaitingList.deleteListNode(&waiting_list, key, NULL);
		call CoapPdu.delete(request_conn->pdu);
        call CoapConnectionPool.put(request_conn);
        goto clean_response;
	
	clean_response:
        call CoapPdu.delete(response);
  }
}
