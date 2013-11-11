#include "include/coap_option.h"

generic configuration CoapOptionC(uint8_t max) {
    provides interface CoapOption;
} implementation {
    components new CoapOptionP();
    CoapOption = CoapOptionP;

    components new PoolC(coap_option_t, max) as OptionPool;
    CoapOptionP.OptionPool -> OptionPool;
}
