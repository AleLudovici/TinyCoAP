#include "resources/resources.h"

module CoapExampleServerP {
  uses {
    interface Boot;
    interface CoapServer;
    interface CoapPdu;
  }
} implementation {
	uint32_t rate = 10048; /* Rate of observe updates */

    event void Boot.booted() {                
    
    }

    event void CoapServer.booted() {
        call CoapServer.init(COAP_DEFAULT_PORT, urikey_map, 1);
        call CoapServer.state(rate, KEY_TEST);            
    }
}
