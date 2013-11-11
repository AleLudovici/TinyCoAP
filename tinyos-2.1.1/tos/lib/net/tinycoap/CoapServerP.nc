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
#include "include/coap_general.h"
#include "include/coap_pdu.h"
#include "include/coap_option.h"
#include "include/coap_list.h"

module CoapServerP {
    provides interface CoapServer;
    uses {
        interface Boot;
        interface SplitControl as RadioControl;
        interface UDP as UdpServer;
        interface CoapPdu;
        interface CoapOption;
		interface Timer<TMilli> as Timers[uint8_t num];
		interface CoapResource[uint8_t id];
        interface Queue<coap_pdu_t *> as IncomingQueue;
        interface Queue<coap_pdu_t *> as ProcessingQueue;
        interface Pool<coap_connection_t> as CoapConnectionPool;
        interface CoapList as WaitingList;
        interface Random;
    }
} implementation {    
    uint8_t buffer[MAX_PACKET_LEN];
    uint16_t pdu_len;
    char uri_req[MAX_URI_LEN];
    double random_factor = 1.5; /* CoAP default value */
    uint8_t idc = 0, uri_len = 0; /* ID of Timers */
 
    /* the address of the Proxy */
    struct sockaddr_in6 dest;
    
    /* uri keymap */  
    key_uri_t *urimap;
    uint8_t urimap_len = 1;

    coap_list_t waiting_list;

    task void processIncomingTask();
    task void processResourcesTask();

    static error_t send(coap_pdu_t *pdu) {
        /* Write the packet and pass it to UDP*/
        if (call CoapPdu.packetWrite(pdu, buffer, &pdu_len) == SUCCESS){
          	if (call UdpServer.sendto(&pdu->addr, buffer, pdu_len) == SUCCESS)
          		return SUCCESS;     
        }
        return FAIL;
    }

    /* match URI with KEY */
    static uint8_t getKey(uint8_t* uri, uint8_t len) {
        uint8_t i;
        
        for (i = 0; i <= urimap_len; i++) {           
	        if (strncmp(urimap[i].uri, uri, len) == 0)
	          return urimap[i].key;
        }       
        return 0;
	}

    /* .well-known/core interface */
    static void getWellKnownCore(uint8_t *output) {
        uint8_t i;

        for (i = 0; i < urimap_len; i++) {
            sprintf(output, "%s<%s>", output, urimap[i].uri);
            if (urimap[i].rt) 
                sprintf(output, "%s;rt=%s;", output ,urimap[i].rt);
            if (urimap[i].iff) 
                sprintf(output, "%sif=%s;", output, urimap[i].iff);
            if (urimap[i].sz) 
                sprintf(output, "%ssz=%d;", output, urimap[i].sz);
            if (urimap[i].ct) 
            	sprintf(output, "%sct=%d;", output, urimap[i].ct);
            if (urimap[i].is_observe) 
                sprintf(output, "%sobs=%d;", output, urimap[i].is_observe);
            if ((i+1) < urimap_len)
            	sprintf(output, "%s%s", output, ','); 
        }
    }

    command error_t CoapServer.init(uint16_t port, key_uri_t *map, uint8_t map_len) {
        urimap = map;
        urimap_len = map_len;
        return call UdpServer.bind(port);
    }


    event void Boot.booted() {
        call RadioControl.start();
        call WaitingList.initList(&waiting_list);   	
        signal CoapServer.booted();
    }

    event void RadioControl.startDone(error_t e) {}

    event void RadioControl.stopDone(error_t e) {}
    
    /*
	* Received a new packet. Add to the processing list and launch a
	* Process task.
	*/
    event void UdpServer.recvfrom(struct sockaddr_in6 *from, void *data, 
                           uint16_t len, struct ip_metadata *meta) {
        coap_pdu_t *pdu;

        if ((pdu = call CoapPdu.create()) == NULL) {
            return;
        }
  		     
        /* Read the CoAP packet */
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
        coap_pdu_t *request;
        coap_option_t *token, *token_conn;
        coap_connection_t *sconn;
        coap_list_index_t *li;
		uint16_t key = 0, len = 0;
		uint8_t token_value[MAX_OPT_DATA], media [sizeof(uint8_t)];
        
        if (call IncomingQueue.empty()) 
            return;

        request = call IncomingQueue.dequeue();
        switch (request->hdr.type) { 
            case COAP_MESSAGE_CON:
            case COAP_MESSAGE_NON:  
            	if (call CoapPdu.checkOptions(request) == FAIL) { 
        			/* Bad Option */
        			call CoapPdu.clean(request, 1);
        			request->hdr.type = COAP_MESSAGE_ACK;
                    request->hdr.code = COAP_RESPONSE_402;
					request->payload_len = 0;
					send(request);
                    goto clean_request;
                    return;
                 }
				    
				 /* Parse URI */
				 uri_len = call CoapPdu.parsing(request, uri_req, COAP_OPTION_URI_PATH);                
				 
				 if (uri_len == 0){
				    /* Bad request. No URI  */
                    call CoapPdu.clean(request, 1);
                    request->hdr.type = COAP_MESSAGE_ACK;
                    request->hdr.code = COAP_RESPONSE_400;	
		   	 		request->payload_len = 0;
                    send(request);
                    goto clean_request;
				  }

                if (strncmp(uri_req, ".well-known/core", strlen(".well-known/core")) == 0) {
                    /* Request to well-known interface */
                    if (call CoapPdu.getOption(request, COAP_OPTION_TOKEN, &token) == SUCCESS){
                    	memcpy(token_value, token->value, token->len);
                    	len = token->len;
                    }
                    call CoapPdu.clean(request, 1);
                    request->hdr.type = COAP_MESSAGE_ACK;
                    request->hdr.code = COAP_RESPONSE_205;
                    media[0] = COAP_MEDIATYPE_APPLICATION_LINK_FORMAT;
                    call CoapPdu.insertOption(request, COAP_OPTION_CONTENT_FORMAT, media, sizeof(uint8_t));
                    if (len != 0)
                    	call CoapPdu.insertOption(request, COAP_OPTION_TOKEN, token_value, len);                    	
                    getWellKnownCore(request->payload);
                    request->payload_len = strlen(request->payload);     
                    send(request);
                    goto clean_request;
                } else { 
                	/* Requesting a resource, add to the queue */
                    if (call ProcessingQueue.enqueue(request) == FAIL) {
                        goto clean_request; 
                    }
                    post processResourcesTask();
                    return;
                }
                break;

            case COAP_MESSAGE_ACK:
                for (li = call WaitingList.first(&waiting_list);li;li = call WaitingList.next(li)) {
                    call WaitingList.this(li, &key, (void **)&sconn);
					/* We use the same list for pending ACK and Separate Response */
					if(!(sconn->is_separate_response)){
						if (sconn->pdu->hdr.id == request->hdr.id) {
					    	if ((call CoapPdu.getOption(request, COAP_OPTION_TOKEN, &token) == SUCCESS)
							&& (call CoapPdu.getOption(sconn->pdu, COAP_OPTION_TOKEN, &token_conn) == SUCCESS)) {
								if (strcmp(token->value, token_conn->value) != 0) {
									/* Token is Wrong send and RST */
									call CoapPdu.clean(request, 1);
									request->hdr.type = COAP_MESSAGE_RST;
									request->hdr.code = COAP_RESPONSE_400;
									request->payload_len = 0;
									send(request);
									goto clean_request;
								} 		    
					    		/* We received an ACK or send a RST. Stop the relative RTX Timer */
								call Timers.stop[key]();
								call WaitingList.deleteListNode(&waiting_list, key, NULL);
								idc -= 1;							
                        		call CoapPdu.delete(sconn->pdu);
                       			call CoapConnectionPool.put(sconn);
								goto clean_request;
							} 
						} 
					} 
				}         
               break;
            case COAP_MESSAGE_RST:
			/* Something went wrong */
				goto clean_request;			
                break;
            default:
                break;
        }
	clean_request:
        call CoapPdu.delete(request);
    }

    task void processResourcesTask() {
        coap_pdu_t *pdu;
        //coap_option_t *opt;
    	
        if (call ProcessingQueue.empty())
         return;
	
        pdu = call ProcessingQueue.dequeue();
		
		//call CoapPdu.getOption(pdu, COAP_OPTION_URI_PATH, &opt);
        /* Call the appropriate resource handler */
        call CoapResource.handle[getKey((uint8_t *)uri_req, uri_len)](pdu, 0);
    }


    event void CoapResource.isSeparateResponse[uint8_t id](coap_pdu_t *response) {
        coap_pdu_t *pdu;
        coap_option_t *opt;
        coap_connection_t *conn;

        if ((pdu = call CoapPdu.create()) == NULL) 
            return;
        
        /* Set Token */
        call CoapPdu.getOption(response, COAP_OPTION_TOKEN, &opt);        	
        call CoapPdu.insertOption(pdu, COAP_OPTION_TOKEN, opt->value, opt->len);
        
        if ((conn = call CoapConnectionPool.get()) == NULL){
            pdu->hdr.type = COAP_MESSAGE_RST;
        	pdu->hdr.code = COAP_RESPONSE_500;
			goto send_message;
 		}
 		        
        /* Insert connection in the Waiting List */
		conn->pdu = response;
		conn->nretransmit = 0;
		conn->is_separate_response = 1;
		conn->uri_id = id;
		conn->is_observe = 0;
		conn->rtx_timer = 3072; /* 3 sec */
		idc += 1;
								
		if ((call WaitingList.insertListNode(&waiting_list, idc, conn) == FAIL)
			|| idc >= WAITING_LIST) {           
			/* Send a RST */
			idc -= 1;
			call CoapConnectionPool.put(conn);
			pdu->hdr.type = COAP_MESSAGE_RST;
        	pdu->hdr.code = COAP_RESPONSE_500;
			goto send_message;       	
		} else {
			/* Empty ACK */       
        	pdu->hdr.type = COAP_MESSAGE_ACK;
        	pdu->hdr.code = 0;
        	goto send_message;
        }
    
    send_message:
	    pdu->hdr.id = response->hdr.id;
        pdu->addr = response->addr;
		if (send(pdu) == SUCCESS){
		 	if (pdu->hdr.type == COAP_MESSAGE_ACK){
				call Timers.startOneShot[idc](conn->rtx_timer);
			} else
				call CoapPdu.delete(response);			
		} else {
			if (pdu->hdr.type == COAP_MESSAGE_ACK)
				idc -= 1;
			call CoapPdu.delete(response);
		}    	  
		call CoapPdu.delete(pdu);
	}

    event void CoapResource.isDone[uint8_t id](coap_pdu_t *response, int obs) {
    	coap_connection_t *conn = NULL;
               	
       	if (response->hdr.type == COAP_MESSAGE_CON) {
       		/* Keep until we receive the Ack or the number of re-tx expires */
            if ((conn = call CoapConnectionPool.get()) == NULL) { 
				/* Send a NON instead */
				response->hdr.type = COAP_MESSAGE_NON;
                goto send_message;
            }
			/* Set the rtx timer*/
			conn->rtx_timer = COAP_DEFAULT_ACK_TIMEOUT * random_factor;
			idc += 1;			
			/* Insert connection in the waiting list */			
			conn->pdu = response;
			conn->nretransmit = 0;
			conn->is_separate_response = 0;
			conn->uri_id = id;
			if (obs)
				conn->is_observe = 1;
			/* If we could not store a CON msg then we could not start the RTX algorithm 
			*  Send a NON instead.
			*/
			if ((call WaitingList.insertListNode(&waiting_list, idc , conn) == FAIL)
				|| idc >= WAITING_LIST) {
				call CoapConnectionPool.put(conn);
                /* Send a NON */
                response->hdr.type = COAP_MESSAGE_NON;
                idc -= 1;
                goto send_message;
            }
            goto send_message;            	
         }

	send_message:
		if (send(response) == SUCCESS){
		 	if (response->hdr.type == COAP_MESSAGE_CON)
				call Timers.startOneShot[idc](conn->rtx_timer);
			else 
				call CoapPdu.delete(response);
		} else {
			if (response->hdr.type == COAP_MESSAGE_CON)
				idc -= 1;
			call CoapPdu.delete(response);
		} 
	}

	default command void CoapResource.handle[uint8_t id](coap_pdu_t *response, int send_separate) {
		call CoapPdu.clean(response, 1);
		response->hdr.type = COAP_MESSAGE_RST;
    	response->hdr.code = COAP_RESPONSE_404;
    	signal CoapResource.isDone[id](response, 0);
	}

    /* The RTX or separate Response Timer has Expired*/
    event void Timers.fired[uint8_t num](){
		coap_connection_t *sconn;
		coap_option_t *token;
		
		call WaitingList.getListNode(&waiting_list, num, (void **)&sconn);
			/* We use the same Timer for */
			if (sconn->is_separate_response){
			    idc -= 1;
				sconn->is_separate_response = 0;
				call CoapResource.handle[sconn->uri_id](sconn->pdu, 1);
				call WaitingList.deleteListNode(&waiting_list, num, NULL);
				call CoapPdu.delete(sconn->pdu); 
			} else {
				if (sconn->nretransmit < COAP_DEFAULT_MAX_RETRANSMIT) {
					/* RTX */;
					send(sconn->pdu);
					sconn->nretransmit++;
					sconn->rtx_timer = 2 * sconn->rtx_timer;
					call Timers.startOneShot[num](sconn->rtx_timer);
				} else {
		    		/* We reach the max number of RTX */
		    		if (sconn->is_observe){
		    			/* Delete the observer */
		    			idc -= 1;
		    			call CoapPdu.getOption(sconn->pdu, COAP_OPTION_TOKEN, &token); 
		    			call CoapResource.deleteObserve[sconn->uri_id](token);
		    		}
					call WaitingList.deleteListNode(&waiting_list, num, NULL);
					call CoapPdu.delete(sconn->pdu);
				}
			}
   	}
   	
   	command error_t CoapServer.state(uint32_t rate, uint8_t num){
   		call CoapResource.transfer[num](rate);
   		return SUCCESS;
   	}
   	
   	default command void CoapResource.transfer[uint8_t id](uint32_t state) {

	}
	
	default command void CoapResource.deleteObserve[uint8_t id](coap_option_t *token) {

	}


}


