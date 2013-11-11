#include <coap_resource.h>
/**
  * Interface to CoAP Server.
  *
  * @author Pol Moreno
  * @date   February 28 2011
  */ 

interface CoapServer {
    command error_t init(uint16_t port, key_uri_t *map, uint8_t map_len);
    command error_t state(uint32_t rate, uint8_t num);
    event void booted();  
}
