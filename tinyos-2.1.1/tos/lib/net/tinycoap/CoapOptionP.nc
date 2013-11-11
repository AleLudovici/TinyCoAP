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
 
#include "include/coap_option.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

generic module CoapOptionP() {
    provides interface CoapOption;
    uses {
        interface Pool<coap_option_t> as OptionPool;
    }
} implementation {

    command coap_option_t *CoapOption.create(uint8_t code, uint8_t *str, uint16_t len) {
        coap_option_t *opt;

        if ((opt = call OptionPool.get()) == NULL)
            return NULL;

        if (len > MAX_OPT_DATA)
            return NULL;

        opt->number = code;
        memset(opt->value, 0, MAX_OPT_DATA);
        memcpy(opt->value, str, len);    
        opt->len = len;

        return opt;
    }

    command void CoapOption.delete(coap_option_t *opt) {
        call OptionPool.put(opt);
    }  
}


