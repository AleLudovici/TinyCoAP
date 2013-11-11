/**
  * Resource Interface.
  *
  * @author Pol Moreno
  * @date   February 28 2011
  */ 

interface CoapResource {

    command void deleteObserve(coap_option_t *token);
    
    command void handle(coap_pdu_t *request, int send_separate);

	command void transfer(uint32_t state);	

    event void isSeparateResponse(coap_pdu_t *response);

    event void isDone(coap_pdu_t *response, int obs);
}
