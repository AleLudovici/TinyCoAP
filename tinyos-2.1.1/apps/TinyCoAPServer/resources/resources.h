#ifndef _COAP_RESOURCES_H_
#define _COAP_RESOURCES_H_  

#include <coap_resource.h>
#include <coap_general.h>
#include <coap_pdu.h>

/* Define here the resource that this server expose */

enum {
    KEY_TEST = 1, /* The parameter of the resource */
};

/* Key_uri_t structure defined at coap_resource.h */
key_uri_t urikey_map[1] = {
    {KEY_TEST, "test", sizeof("test"),
    "testing", "example", MAX_PAYLOAD,
    COAP_MEDIATYPE_TEXT_PLAIN, 1},
};
#endif
