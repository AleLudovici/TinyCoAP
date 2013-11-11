#ifndef _COAP_PDU_H_
#define _COAP_PDU_H_

#include <ip.h>

#include "coap_option.h"
#include "coap_list.h"

/* CoAP message types */
enum {
	COAP_MESSAGE_CON = 0, /* confirmable message (requires ACK/RST) */
	COAP_MESSAGE_NON = 1, /* non-confirmable message (one-shot message) */
	COAP_MESSAGE_ACK = 2, /* used to acknowledge confirmable messages */
	COAP_MESSAGE_RST = 3 /* indicates error in received messages */
};
/* CoAP pdu methods */

enum {
	COAP_REQUEST_GET = 1,
	COAP_REQUEST_POST = 2,
	COAP_REQUEST_PUT = 3,
	COAP_REQUEST_DELETE = 4
};

/* CoAP result codes (HTTP-Code / 100 * 40 + HTTP-Code % 100) */

enum {
	COAP_RESPONSE_201 = 65,  /* Created */
	COAP_RESPONSE_202 = 66,  /* Deleted */
	COAP_RESPONSE_203 = 67,  /* Valid */
	COAP_RESPONSE_204 = 68,  /* Changed */
	COAP_RESPONSE_205 = 69,  /* Content */
	COAP_RESPONSE_400 = 128, /* Bad Request */
	COAP_RESPONSE_401 = 129, /* Unauthorized */
	COAP_RESPONSE_402 = 130, /* Bad Option */
	COAP_RESPONSE_403 = 131, /* Forbidden */
	COAP_RESPONSE_404 = 132, /* Not Found */
	COAP_RESPONSE_405 = 133, /* Method Not Allowed */
	COAP_RESPONSE_406 = 134, /* Not Acceptable */
	COAP_RESPONSE_412 = 140, /* Precondition Failed */
	COAP_RESPONSE_413 = 141, /* Request Entity Too Large */
	COAP_RESPONSE_415 = 143, /* Unsupported Media Type */
	COAP_RESPONSE_500 = 160, /* Internal Server Error */
	COAP_RESPONSE_501 = 161, /* Not Implemented */
	COAP_RESPONSE_502 = 162, /* Bad Gateway */
	COAP_RESPONSE_503 = 163, /* Service Unavailable */
	COAP_RESPONSE_504 = 164, /* Gateway Timeout */
	COAP_RESPONSE_505 = 165  /* Proxying Not Supported */
};

typedef struct {
    uint8_t version; /* Protocol version */   
    uint8_t type;	/* Message type */
    uint8_t optcnt; /* Number of option */
    uint8_t code;	/* Pdu method (value 1--10) or response code (value 40-255) */
    uint16_t id; /* Transaction id */
} coap_hdr_t;

/** PDU definition **/
typedef struct {
    /* Timestamp used to check the MAXAGE option */
    uint8_t timestamp;
    /* Header */
    coap_hdr_t hdr;
    /* Origin address */
    struct sockaddr_in6 addr;
    uint8_t payload[MAX_PAYLOAD];
    uint16_t payload_len;
    /* Option list */
    coap_list_t opt_list;
} coap_pdu_t;

#endif
