#ifndef _COAP_OPTION_H_
#define _COAP_OPTION_H_

typedef struct {
    uint8_t number;
    uint16_t len;
    uint8_t value[MAX_OPT_DATA];
} coap_option_t;

/* CoAP options and the corresponding numbers */
enum {
	  COAP_OPTION_IF_MATCH = 1, 		/* opaque 0-8 B*/
	  COAP_OPTION_URI_HOST = 3,	 		/* string, 1-255 B*/
	  COAP_OPTION_ETAG = 4, 			/* opaque, 1-8 B*/
	  COAP_OPTION_IF_NONE_MATCH = 5, 	/* none 0 B */
	  COAP_OPTION_OBSERVE = 6,			/* uint */
	  COAP_OPTION_URI_PORT = 7, 		/* uint, 0-2 B, - */
	  COAP_OPTION_LOCATION_PATH = 8, 	/* String, 0-255 B, - */
	  COAP_OPTION_URI_PATH = 11,  		/* String, 0-255 B, - */
	  COAP_OPTION_CONTENT_FORMAT = 12, 	/* uint, 0-2 B*/
	  COAP_OPTION_MAXAGE = 14, 			/* uint, 0-4 B, 60 Seconds */
	  COAP_OPTION_URI_QUERY = 15, 		/* string, 1-255 B*/
	  COAP_OPTION_ACCEPT = 16, 			/* uint 0-2 B */
	  COAP_OPTION_TOKEN = 19, 			/* opaque, 1-8 B, - */
	  COAP_OPTION_LOCATION_QUERY = 20, 	/* string, 0-255 B, - */
	  COAP_OPTION_BLOCK2 = 23,
	  COAP_OPTION_BLOCK1 = 27,
	  COAP_OPTION_SIZE = 28,
	  COAP_OPTION_PROXY_URI = 35, 		/* string, 1-1034 B */
};
#endif
