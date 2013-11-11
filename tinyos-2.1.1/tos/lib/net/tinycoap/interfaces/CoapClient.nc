/**
  * Interface to CoAP Client.
  *
  * @author Pol Moreno
  * @date   February 28 2011
  */ 
#include "../include/coap_pdu.h"

interface CoapClient
{
	command void sendRequest(coap_pdu_t *request);
	event void messageReceived(coap_pdu_t *response);
    event void failedtx();
}
