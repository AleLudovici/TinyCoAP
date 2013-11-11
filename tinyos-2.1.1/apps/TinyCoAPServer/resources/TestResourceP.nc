#include <coap_pdu.h>
#include <coap_general.h>
#include <IPDispatch.h>
#include <lib6lowpan.h>
#include <ip.h>
#include "string.h"

module TestResourceP {
    provides interface CoapResource;
    uses {
        interface CoapList as ObserversCtrList;
        interface CoapPdu;
        interface Pool<coap_observe_t> as addrPool;
        interface Timer<TMilli> as Timer0;
        interface Random;
    }
} implementation {

		coap_list_t list;
		uint8_t obsvalue = 0, media [sizeof(uint8_t)];
		int obs_list = 0;       
       	/* Initialize the Message ID and Token values*/
		uint16_t token_gen = 1;
		uint16_t id_gen = 1;
		
   command void CoapResource.handle(coap_pdu_t *request, int send_separate) {
        coap_list_index_t *li;
        coap_option_t *token, *obs;
        coap_observe_t *observer;
        char tmp[3];
        uint8_t tk_value[MAX_OPT_DATA];
        uint16_t len = 0;

        switch(request->hdr.code){        
			case COAP_REQUEST_GET:
				if (call CoapPdu.getOption(request, COAP_OPTION_TOKEN, &token) == SUCCESS){
		    		memcpy(tk_value, token->value, token->len);
		    		len = token->len;
		    	}		    		
				/* Check if we received a Observe request */								
				if (call CoapPdu.getOption(request, COAP_OPTION_OBSERVE, &obs) == SUCCESS){
					/* Check in the observer's list if the client is already registered */
					for (li = call ObserversCtrList.first(&list);li;li = call ObserversCtrList.next(li)) {
						call ObserversCtrList.this(li, NULL, (void **)&observer);
						if(memcmp(&(request->addr), &(observer->addr), sizeof(struct sockaddr_in6)) == 0) {
							if (call CoapPdu.getOption(request, COAP_OPTION_OBSERVE, &obs) == SUCCESS){
								/* Update the token value */
								li->this->key = atoi(tk_value);
								goto send_request_response;
							} else { 
								/* Remove from the observers */
								call ObserversCtrList.deleteListNode(&list, li->this->key, NULL);
								call addrPool.put(observer);
								goto send_request_response;
                			}	
		    			}
					 }
								
					/* Init the list */		
					call ObserversCtrList.initList(&list);
							    			    		
		    		/* Clear Option and re-use PDU */
		    		call CoapPdu.clean(request, 1);
		    		
		    		/* If Observers List is Full then Reply with a normal answer */
					if ((observer = (coap_observe_t *) call addrPool.get()) == NULL)						
						goto send_request_response;					
											
					/* Fill the coap_observer_t struct */
					observer->addr = request->addr;
					memcpy(observer->token, tk_value, len);
					observer->len = len;
				
					/* Insert the observer in the list */ 			
					if (call ObserversCtrList.insertListNode(&list, atoi(observer->token), observer) == SUCCESS){
						sprintf(tmp, "%i", obsvalue);
						call CoapPdu.insertOption(request, COAP_OPTION_OBSERVE, tmp, strlen(tmp));
						obs_list++;
					} 
					goto send_request_response;										
    			} else {
    				/* Piggy-Backed and Separate Response when I have observers 
    				*  NOTE: Separate Response need a more sophisticated approach. This is just for testing it!! 
    				*/
    				if ((obs_list != 0) && (!send_separate)){
						signal CoapResource.isSeparateResponse(request);
						return;
					}  				
    				call CoapPdu.clean(request, 1);
					goto send_request_response;	
				}
				break;
			case COAP_REQUEST_POST:
				break;
			case COAP_REQUEST_PUT:
				break;
			case COAP_REQUEST_DELETE:
				break;
			default:
				break;
			}		

send_request_response:
			request->hdr.type = COAP_MESSAGE_ACK;
			request->hdr.code = COAP_RESPONSE_205;
			media[0] = COAP_MEDIATYPE_TEXT_PLAIN;
            call CoapPdu.insertOption(request, COAP_OPTION_CONTENT_FORMAT, media, sizeof(uint8_t));
			if (len != 0)
				call CoapPdu.insertOption(request, COAP_OPTION_TOKEN, tk_value, len);
			memcpy(request->payload, "This is a Test\0", strlen("This is a Test\0"));
    		request->payload_len = strlen("This is a Test\0");
			signal CoapResource.isDone(request, 0);	
}
	
    command void CoapResource.transfer(uint32_t rate) {
     	/* Start a timer to send periodical observe updates */
     	call Timer0.startPeriodic(rate);
    }
    
    command void CoapResource.deleteObserve(coap_option_t *token){
    	coap_list_index_t *li;
    	coap_observe_t *observer;
    	
    	for (li = call ObserversCtrList.first(&list);li;li = call ObserversCtrList.next(li)) {
			call ObserversCtrList.this(li, NULL, (void **)&observer);			
			if (atoi(token->value) == li->this->key){
				call ObserversCtrList.deleteListNode(&list, li->this->key, NULL);
			}
		}
		    
    } 
    
    event void Timer0.fired(){
    	coap_observe_t *obs;
        coap_list_index_t *li;
		uint16_t key;
		coap_pdu_t *pdu = NULL;
		char tmp[3];

		if (obs_list != 0){
		for (li = call ObserversCtrList.first(&list);li;li = call ObserversCtrList.next(li)) {
			call ObserversCtrList.this(li, &key, (void **)&obs);
			if ((pdu = (coap_pdu_t *) call CoapPdu.create()) != NULL){
			    /* Set the header */
			    pdu->hdr.type = COAP_MESSAGE_CON;
			    pdu->hdr.code = COAP_RESPONSE_205;
			    pdu->hdr.id = id_gen;
			    pdu->addr = obs->addr;
			    
			    /* Add Token, COntent type and Observe Options*/
			    sprintf(tmp, "%i", obsvalue);            	
				call CoapPdu.insertOption(pdu, COAP_OPTION_OBSERVE, tmp, strlen(tmp));
				media[0] = COAP_MEDIATYPE_TEXT_PLAIN;
            	call CoapPdu.insertOption(pdu, COAP_OPTION_CONTENT_FORMAT, media, sizeof(uint8_t));
				call CoapPdu.insertOption(pdu, COAP_OPTION_TOKEN, obs->token, obs->len);
												
				/* Set the payload */
				memcpy(pdu->payload, "Update\0", strlen("Update\0"));
				pdu->payload_len = strlen("Update\0");

				/* Send it */
				signal CoapResource.isDone(pdu, 1);
            	
            	/* Update Messagge ID */
            	id_gen = (id_gen + 1) % 65536;
        	} else {
             /* No More Space Available*/
            }
		}
		/* Next value of the observe option*/        
		obsvalue = (obsvalue + 1) % 256;
	 }
    } 
}