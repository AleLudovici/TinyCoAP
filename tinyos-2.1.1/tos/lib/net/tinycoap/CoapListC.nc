#include "include/coap_list.h"

generic configuration CoapListC(uint8_t max) {
    provides interface CoapList;
} implementation {
    components new CoapListP();
    CoapList = CoapListP;

    components new PoolC(coap_node_t, max) as NodePool;
    CoapListP.NodePool -> NodePool;
}
