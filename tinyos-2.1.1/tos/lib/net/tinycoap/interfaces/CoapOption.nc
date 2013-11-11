/**
  * CoapOption Interface.
  *
  * @author Pol Moreno
  * @date   February 28 2011
  */ 

interface CoapOption {
    command coap_option_t *create(uint8_t code, uint8_t *str, uint16_t len);

    command void delete(coap_option_t *opt);
}
