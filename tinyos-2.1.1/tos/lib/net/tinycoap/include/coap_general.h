#ifndef _COAP_GENERAL_H_
#define _COAP_GENERAL_H_
#include "coap_pdu.h"

enum {
    COAP_DEFAULT_ACK_TIMEOUT = 1048, 	/* RTO in milliseconds */
    COAP_DEFAULT_MAX_RETRANSMIT = 1, 	/* max number of retransmissions */
    COAP_DEFAULT_PORT = 5683, 			/* CoAP default UDP port */
    COAP_DEFAULT_MAX_AGE = 60, 			/* default maximum object lifetime in seconds */
    COAP_DEFAULT_VERSION = 1, 			/* supported CoAP version */
};

/* CoAP media type encoding accepted by TinyCoAP */
enum {
    COAP_MEDIATYPE_TEXT_PLAIN = 0, /* text/plain;charset=utf-8 (UTF-8) */
    COAP_MEDIATYPE_APPLICATION_LINK_FORMAT = 40, /* application/link-format */
};

/* coap_connection_t keep track of ongoing communications with a server */
typedef struct {
    coap_pdu_t *pdu; /* The PDU we sent and we may have to rtx */
    uint8_t nretransmit; /* current number of rtx */
    uint8_t is_separate_response; /* indicate if we should wait for a separate response */
    uint32_t rtx_timer;
    uint8_t is_observe;
    uint8_t uri_id;
} coap_connection_t;

/* coap_observe_t contains info of observers */
typedef struct {
	uint8_t token[MAX_OPT_DATA]; /* The token to be used in the updates  */
	uint16_t len;
	struct sockaddr_in6 addr; /* the address of the observer */
}coap_observe_t;

#endif
