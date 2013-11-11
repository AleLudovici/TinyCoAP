#include "include/coap_pdu.h"

generic configuration CoapPduC(uint8_t max) {
  provides interface CoapPdu;
} 
implementation {
    components new CoapPduP();
    CoapPdu = CoapPduP;

    components new CoapOptionC(MAX_OPT);
    CoapPduP.CoapOption -> CoapOptionC;

    components new PoolC(coap_pdu_t, max);
    CoapPduP.Pool -> PoolC;    

    components new CoapListC(MAX_OPT) as OptionList;
    CoapPduP.OptionList -> OptionList;
}
