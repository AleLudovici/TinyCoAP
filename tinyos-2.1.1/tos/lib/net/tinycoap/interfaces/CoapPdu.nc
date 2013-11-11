/**
  * CoapPdu Interface.
  *
  * @author Pol Moreno
  * @date   February 28 2011
  */ 

interface CoapPdu {

    command coap_pdu_t *create();

    command void delete(coap_pdu_t *pdu);

    command void clean(coap_pdu_t *pdu, int options); /* If options is 1 clean only the options */

    command error_t packetWrite(coap_pdu_t *pdu, uint8_t *buffer, uint16_t *len);

    command error_t packetRead(uint8_t *buffer, uint16_t packet_len, coap_pdu_t *pdu);

    command error_t insertOption(coap_pdu_t *pdu, uint8_t code, uint8_t *str, uint16_t len);

    command error_t getOption(coap_pdu_t *pdu, uint8_t code, coap_option_t **opt);

    command error_t unsetOption(coap_pdu_t *pdu, uint8_t code);

    command error_t checkOptions(coap_pdu_t *pdu);

    command uint8_t parsing(coap_pdu_t *pdu, char *uri, uint8_t option_num);
    
    command uint8_t size();

    command uint8_t maxSize();
}
