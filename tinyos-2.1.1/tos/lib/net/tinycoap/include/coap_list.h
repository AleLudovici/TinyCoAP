#ifndef _COAP_LIST_H_
#define _COAP_LIST_H_

struct coap_node_t {
    struct coap_node_t *next;
    uint16_t key;
    void *data;
};

struct coap_list_index_t {
    struct coap_list_t *list;
    struct coap_node_t *this, *next;
};

struct coap_list_t {
    struct coap_node_t *first;
    struct coap_list_index_t  iterator;//no se usa
};

typedef struct coap_list_t coap_list_t;
typedef struct coap_node_t coap_node_t;
typedef struct coap_list_index_t coap_list_index_t;

#endif
