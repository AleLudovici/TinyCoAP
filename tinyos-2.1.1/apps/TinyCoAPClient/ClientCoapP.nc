#include <IPDispatch.h>
#include <lib6lowpan.h>
#include <ip.h>
#include <string.h>
#include <stdio.h>

#include "coap_pdu.h"
#include "coap_general.h"
#include "coap_option.h"
#include "printf.h"


module ClientCoapP {
  uses {
    interface Boot;
    interface CoapClient;
    interface CoapPdu;
    interface Timer<TMilli> as Timer0;
    interface Random;
  }
} implementation {

	coap_pdu_t *request = NULL;
	uint16_t token_gen, id_gen;
	struct sockaddr_in6 dest;
	char uri[MAX_URI_LEN];
	uint8_t ok_send = 0;
			
	event void Boot.booted() {
		call Timer0.startOneShot(12400);
		/* Initialize the Message ID and Token values*/
		token_gen = call Random.rand16();
		id_gen = call Random.rand16();
		/* This is the server address */
		dest.sin6_port = hton16(COAP_DEFAULT_PORT);
		inet_pton6("fec0::1", &dest.sin6_addr);
	}

	event void Timer0.fired(){
		char tmp_token[8];
		
		if ((request = (coap_pdu_t *) call CoapPdu.create()) != NULL){
			/* Insert Message type, method and the destination address */
			request->hdr.type = COAP_MESSAGE_CON;
			request->hdr.code = COAP_REQUEST_GET;
			request->addr = dest;
			
			/* Insert Message ID */
        	request->hdr.id = id_gen;
        				
			/* Insert Options */  
			if (ok_send){
				call CoapPdu.insertOption(request, COAP_OPTION_OBSERVE, NULL, 0);
				call CoapPdu.insertOption(request, COAP_OPTION_URI_PATH, uri, strlen(uri));
			} else {
				call CoapPdu.insertOption(request, COAP_OPTION_URI_PATH, ".well-known", strlen(".well-known"));
				call CoapPdu.insertOption(request, COAP_OPTION_URI_PATH, "core", strlen("core"));
			}
			
	    	/* Token */
	    	sprintf(tmp_token, "%i", token_gen);		
			call CoapPdu.insertOption(request, COAP_OPTION_TOKEN, tmp_token, strlen(tmp_token));

			call CoapClient.sendRequest(request);
			/* Calculate the new token and message ID */
			token_gen = (token_gen + 1) % 65536;
			id_gen = (id_gen + 1) % 65536;			
		}	
	}	

	event void CoapClient.messageReceived(coap_pdu_t *response){
		coap_option_t *token, *ct;
		uint8_t tk_buffer[MAX_OPT_DATA], uri_len = 0;
		uint16_t len = 0;
		char *p = NULL, *q = NULL;
		
		/* Manage here the piggy-backed response and the observe updates */				
		/* Succesfull request 2.xx */
		if (response->hdr.code <= COAP_RESPONSE_205){
			switch(response->hdr.code){
				case COAP_RESPONSE_201:
					break;
				case COAP_RESPONSE_202:
					break;
				case COAP_RESPONSE_203:
					break;
				case COAP_RESPONSE_204:
					break;
				case COAP_RESPONSE_205:
					if (call CoapPdu.getOption(response, COAP_OPTION_CONTENT_FORMAT, &ct) == SUCCESS){
						switch(ct->value[0]){
							case COAP_MEDIATYPE_TEXT_PLAIN:
								/* Print it */
								printf("%s\n", response->payload);
								printfflush();								
								break;
							case COAP_MEDIATYPE_APPLICATION_LINK_FORMAT:
								/* Response to a GET .well-known/core */
								p = &response->payload;
								q = p;
								if (*p == '<'){
									p++;
									q++;
								} 
								while (*p != '>')						
									p++;														
								uri_len = p-q;
								memcpy(uri, q, uri_len);
								ok_send = 1;
						    	call Timer0.startOneShot(1024);
						    	break;
						    default:
						    	break;
						}
					} 
					break;
				default:
	
				break;
			}			
			/* Send an empty ACK if CON */
			if(response->hdr.type == COAP_MESSAGE_CON){	
				if (call CoapPdu.getOption(response, COAP_OPTION_TOKEN, &token) == SUCCESS){
					memcpy(tk_buffer, token->value, token->len);
					len = token->len;
				}				
				/* Don't waste memory. Re-use the PDU */
				call CoapPdu.clean(response,1);				
				if (len != 0)
					call CoapPdu.insertOption(response, COAP_OPTION_TOKEN, tk_buffer, len);
				
				response->hdr.type = COAP_MESSAGE_ACK;    		
    				response->hdr.code = 0;
    				call CoapClient.sendRequest(response);    			
			}
		} else if (response->hdr.code <= COAP_RESPONSE_505) {
			/* Handle here 4.xx and 5.xx error codes */
			switch(response->hdr.code){
				case COAP_RESPONSE_401:
					break;
				case COAP_RESPONSE_402:
					break;
				case COAP_RESPONSE_403:
					break;
				case COAP_RESPONSE_404:
					break;
				case COAP_RESPONSE_405:
					break;
				case COAP_RESPONSE_406:
					break;	
				case COAP_RESPONSE_412:
					break;
				case COAP_RESPONSE_413:
					break;
				case COAP_RESPONSE_415:
					break;
				case COAP_RESPONSE_500:
					break;
				case COAP_RESPONSE_501:
					break;
				case COAP_RESPONSE_502:
					break;
				case COAP_RESPONSE_503:
					break;
				case COAP_RESPONSE_504:
					break;
				case COAP_RESPONSE_505:
					break;
				default:
					break;		
				}				
			}
	}
			
	event void CoapClient.failedtx(){
		/* Handler for failed transmission  */
	}
}
