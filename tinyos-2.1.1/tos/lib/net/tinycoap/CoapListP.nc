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
 
#include "include/coap_list.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

generic module CoapListP() {
    provides interface CoapList;
    uses {
        interface Pool<coap_node_t> as NodePool;
    }
} implementation {
    
    command void CoapList.initList(coap_list_t *list) {
        if(list->first==NULL){
			memset(list,0,sizeof(coap_list_t));
	        list->first = NULL;
		}
   }

    command coap_node_t *CoapList.createListNode(uint16_t key, void *data) {
        coap_node_t *node;

        if ((node = call NodePool.get()) == NULL) {
            return NULL;
        }
        node->next = NULL;
        node->key = key;
        node->data = data;
        return node;
    }

    command error_t CoapList.insertListNode(coap_list_t *list, uint16_t key, void *data) {
         coap_node_t *node, *p, *q;

         if ((node = call CoapList.createListNode(key,data)) == NULL) {
            return FAIL;
         }

         /* set queue head if empty */
         if (!list->first) {
            list->first = node;
            return SUCCESS;
         }
  
         /* Order The List...Important for Options */
         q = list->first;
         if (node->key < q->key ) {
             node->next = q;
             list->first = node;
             return SUCCESS;
         }

        /* search for right place to insert */
        do {
            p = q;
            q = q->next;
        } while ( q && ( node->key >= q->key ));

        /* insert new item */
        node->next = q;
        p->next = node;
        return SUCCESS;
        
    }

    command error_t CoapList.getListNode(coap_list_t *list, uint16_t key, void **data) {
        coap_node_t *p;
        
        if (!list || !list->first) {
            return FAIL;    
        }

        for (p = list->first; p != NULL; p = p->next) {
            if (p->key == key) {
                if (!p->data) {
                    return FAIL;
                }
                *data = p->data;             
                return SUCCESS;
            }
        }       
        return FAIL;
    }


    command error_t CoapList.deleteListNode(coap_list_t *list, uint16_t key, void **data) {
        coap_node_t *p,*q;

        if (!list || !list->first) {
            return FAIL;
        }

        q = list->first;

        if (q->key == key) {
            list->first = list->first->next;
            if (data) *data = q->data; 
            call NodePool.put(q);
            return SUCCESS;
        }

        for (p = q->next; p != NULL; p = p->next) {
            if (p->key == key) {
                q->next = p->next;
                if (data) *data = p->data;
                call NodePool.put(p);
                return SUCCESS;
            }
            q = p;
        }

        return FAIL;
    }

    command coap_list_index_t *CoapList.next(coap_list_index_t *li) {
        li->this = li->next;
        if (!li->this) {
            return NULL;
        }
        li->next = li->this->next;
        return li;
    }

    command coap_list_index_t *CoapList.first(coap_list_t *list) {
        coap_list_index_t *li;

        if (list->first != NULL) {
            li = &list->iterator;
            li->list = list;
            li->this = list->first;
            li->next = list->first->next;
            return li;
        }
        return NULL;
    }

    command void CoapList.this(coap_list_index_t *li, uint16_t *key, void **data) {
        if (key)  *key  = li->this->key;
        if (data)  *data  = (void *)li->this->data;
    }

    command error_t CoapList.cleanList(coap_list_t *list) {
        coap_list_index_t *li;
        uint16_t key;
        for (li = call CoapList.first(list);li;li = call CoapList.next(li)) {
            call CoapList.this(li,&key,NULL);
            call CoapList.deleteListNode(list,key,NULL);
        }
	
        return SUCCESS;
    }
}





