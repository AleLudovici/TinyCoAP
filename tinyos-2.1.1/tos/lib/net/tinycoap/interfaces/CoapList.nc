/**
  * CoapList Interface.
  *
  * @author Pol Moreno
  * @date   February 28 2011
  */ 
interface CoapList {

    command void initList(coap_list_t *list);

    command coap_node_t *createListNode(uint16_t key, void *data);

    command error_t insertListNode(coap_list_t *list, uint16_t key, void *data);
 
    command error_t getListNode(coap_list_t *list, uint16_t key, void **data);

    command error_t deleteListNode(coap_list_t *list, uint16_t key, void **data);

    command error_t cleanList(coap_list_t *list);

    command coap_list_index_t *next(coap_list_index_t *li);

    command coap_list_index_t *first(coap_list_t *list);

    command void this(coap_list_index_t *li, uint16_t *key, void **data);
}


