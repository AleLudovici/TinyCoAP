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
#include "include/coap_pdu.h"
#include "include/coap_option.h"
#include "include/coap_list.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

generic module CoapPduP() {
    provides interface CoapPdu;
    uses {
        interface Pool<coap_pdu_t> as Pool;
        interface CoapOption as CoapOption;
        interface CoapList as OptionList;
    }
} implementation {
 
    command coap_pdu_t *CoapPdu.create() {
        coap_pdu_t *pdu;

        if ((pdu = call Pool.get()) == NULL) {
            return NULL;
        }

        pdu->hdr.version = COAP_DEFAULT_VERSION;
                
        call OptionList.initList(&pdu->opt_list);
        return pdu;
    }

    command void CoapPdu.delete(coap_pdu_t *pdu) {
        coap_list_index_t *li;
        coap_option_t *opt;

        for (li = call OptionList.first(&pdu->opt_list);li;li = call OptionList.next(li)) {
            call OptionList.this(li,NULL,(void **)&opt);
            call CoapPdu.unsetOption(pdu, opt->number);
        }
        call Pool.put(pdu);
    }


    command void CoapPdu.clean(coap_pdu_t *pdu, int options) {
        coap_list_index_t *li;
        coap_option_t *opt;

        for (li = call OptionList.first(&pdu->opt_list);li;li = call OptionList.next(li)) {
            call OptionList.this(li,NULL,(void **)&opt);
            call CoapPdu.unsetOption(pdu, opt->number);
        }
        
        if(!options)
        	memset(pdu, 0, sizeof(coap_pdu_t));
	else{
		memset(pdu->payload, 0, pdu->payload_len);
		pdu->payload_len = 0;
	}
    }

    command error_t CoapPdu.packetWrite(coap_pdu_t *pdu, uint8_t *buffer, uint16_t *len) {
        uint8_t *pointer = buffer;
        coap_option_t *option;
        coap_list_index_t *li; 
        uint16_t opt, opt_delta = 0, jump = 0;

        *buffer = (((pdu->hdr.version) << 6) | ((pdu->hdr.type) << 4) | (pdu->hdr.optcnt & 0x0F));
        buffer++;

        *buffer = pdu->hdr.code;
        buffer++;

        *((uint16_t *)buffer) = (uint16_t)pdu->hdr.id;
        buffer += 2;

        opt = 0;
        
        for (li = call OptionList.first(&pdu->opt_list);li;li = call OptionList.next(li)) {
            call OptionList.this(li,NULL,(void **)&option);

            opt_delta = option->number - opt;
            opt = option->number;

            if(opt_delta <= 15){
        		*buffer = (opt_delta & 0x0F) << 4;
        	} else if ((opt_delta <= 30)){
        		/* Jump increase by 15 */
        		opt_delta -= 15;
        		*buffer = 0xF1;
        		buffer++;
        		*buffer = (opt_delta & 0x0F) << 4;
        	} else if (opt_delta <= 255){
        		/* add 1 byte to jump */
        		*buffer = 0xF2;
        		buffer++;
        		/* Insert Jump Value */
        		jump = (opt_delta/8)-2;
        		*buffer = jump;
        		buffer++;
        		*buffer = opt_delta - jump;
        	} else {
        		/* add 2 byte to jump*/
        		*buffer = 0xF3;
        		buffer++;
        		/* Insert Jump Value */
        		jump = (opt_delta/8)-258;
        		*buffer = jump/2;
        		buffer++;
        		*buffer = jump/2;
        		*buffer = opt_delta - jump;
        	}
        
            if (option->len > 15) {
                *buffer |= 0x0F;
                buffer++;
                /* extended option */
                *buffer = option->len - 15;
            } else {
                *buffer |= option->len & 0x0F;
            }
            
            buffer++;
            memcpy(buffer, option->value, option->len);
            buffer += option->len;
        }
    
        memcpy(buffer, pdu->payload, pdu->payload_len);
        *len = buffer - pointer + pdu->payload_len;
        
        return SUCCESS;
    }

     command error_t CoapPdu.packetRead(uint8_t *buffer, uint16_t packet_len, coap_pdu_t *pdu) {
        uint8_t *cur;
        uint8_t cnt, optcnt;    
        uint16_t opt_len, opt_code = 0, jump = 0;

        /* pdu must be initialized */
        if (!pdu) {
        	return FAIL;
        }

        call CoapPdu.clean(pdu, 0);

        /* pointer at the beginning of the buffer */
        cur = buffer;
        
        /* fill in the header */
        pdu->hdr.version = (*((uint8_t *)cur) & 0xC0 ) >> 6;
        pdu->hdr.type = (*((uint8_t *)cur) & 0x30 ) >> 4;
        optcnt = *((uint8_t *)cur) & 0x0F;
        cur++;
        pdu->hdr.code = *((uint8_t *)cur);
        cur++;
        pdu->hdr.id = *((uint16_t *)cur);
        cur += 2;
		
        pdu->hdr.optcnt = 0;

        for (cnt = 0; cnt < optcnt; cnt++) {
            /* add delta */
			if(*cur == 0xF1){
    			opt_code += 15;
    			cur++;
    		} else if (*cur == 0xF2){
    			cur++;
    			jump = *cur;
    			opt_code = (jump + 2)*8;
    			cur++;
    		} else if (*cur == 0xF3){
    			cur++;
    			jump = *cur;
    			cur++;
    			jump += *cur;
    			cur++;
    			opt_code = (jump + 258)*8;
    			cur++;
    		}

            opt_code += (*((uint8_t *)cur) & 0xF0) >> 4;
            /* calculate option length */
            opt_len = *((uint8_t *)cur) & 0x0F;
            
            if (opt_len == 15) {
                /* extended length */
                cur++;
                opt_len = 15 + *((uint8_t *)cur);
            }
            cur++;
            /* get option */
            if (call CoapPdu.insertOption(pdu, opt_code, (uint8_t *)cur, opt_len) !=SUCCESS){
                return FAIL;
            }
            cur += opt_len;
        }
        
        pdu->payload_len = packet_len - ((uint8_t *)cur - buffer);
        memcpy(pdu->payload, cur, pdu->payload_len);
        
        return SUCCESS;

    }
    

    command error_t CoapPdu.insertOption(coap_pdu_t *pdu, uint8_t code, uint8_t *str, uint16_t len) {
        coap_option_t *opt;
        
        if ((opt = call CoapOption.create(code, str, len)) == NULL) {
            return FAIL;
        }
        
        pdu->hdr.optcnt++;
        return call OptionList.insertListNode(&pdu->opt_list, opt->number, opt);
    }

    command error_t CoapPdu.getOption(coap_pdu_t *pdu, uint8_t code, coap_option_t **opt) {        
        return call OptionList.getListNode(&pdu->opt_list, code, (void **)opt);
    }

    command error_t CoapPdu.unsetOption(coap_pdu_t *pdu, uint8_t code) {    
        coap_option_t *opt;
        if (call OptionList.deleteListNode(&pdu->opt_list, code, (void **)&opt) == FAIL) {
            return FAIL;
        }

        call CoapOption.delete(opt);

        if (pdu->hdr.optcnt > 0)
		    pdu->hdr.optcnt--;
        return SUCCESS;
    }
    
    command error_t CoapPdu.checkOptions(coap_pdu_t *pdu) {
        coap_option_t *option;
        coap_list_index_t *li;
        
        for (li = call OptionList.first(&pdu->opt_list);li;li = call OptionList.next(li)) {
            call OptionList.this(li,NULL,(void **)&option);
            switch (option->number) {
	  			case COAP_OPTION_IF_MATCH:
	  			case COAP_OPTION_URI_HOST:
	  			case COAP_OPTION_ETAG:
	  			case COAP_OPTION_IF_NONE_MATCH:
	  			case COAP_OPTION_OBSERVE:
	  			case COAP_OPTION_URI_PORT:
	  			case COAP_OPTION_LOCATION_PATH:
	  			case COAP_OPTION_URI_PATH:
	  			case COAP_OPTION_CONTENT_FORMAT:
	  			case COAP_OPTION_MAXAGE:
	  			case COAP_OPTION_URI_QUERY:
	  			case COAP_OPTION_ACCEPT:
	  			case COAP_OPTION_TOKEN:
	  			case COAP_OPTION_LOCATION_QUERY:
	  			case COAP_OPTION_BLOCK2:
	  			case COAP_OPTION_BLOCK1:
	  			case COAP_OPTION_SIZE:
	  			case COAP_OPTION_PROXY_URI:
                    break;
                default: //unrecognized option
                    return FAIL;
					break;
            }
        }
      return SUCCESS;
    }
   
    command uint8_t CoapPdu.parsing(coap_pdu_t *pdu, char *uri, uint8_t option_num){
    	coap_option_t *opt;
		coap_list_index_t *li;
		char *p = NULL;
		
		p = uri;
		if (option_num == COAP_OPTION_URI_QUERY){
			*p = '?';
			p++;
		}
		
		/* Parse */
		 for (li = call OptionList.first(&pdu->opt_list);li;li = call OptionList.next(li)) {
            call OptionList.this(li, NULL, (void **)&opt);
			if ((opt->number) == option_num){
				sprintf(p, "%s", opt->value);
				p += opt->len;
				if (option_num == COAP_OPTION_URI_PATH)
					*p = '/';
				else if ((option_num == COAP_OPTION_URI_QUERY))
					*p = '&';
				p++;
			}
		}
		*p='\0';
		
		/* return uri length */
		return p - uri - 1;
    } 
   
   command uint8_t CoapPdu.size(){
	return call Pool.size();
  }
  command uint8_t CoapPdu.maxSize(){
	return call Pool.maxSize();
	}
}
