#ifndef _COAP_RESOURCE_H_
#define _COAP_RESOURCE_H_  

typedef struct key_uri {
    uint8_t key;		/* Parametrized resource */
    uint8_t uri[MAX_URI_LEN]; /* URI of the resource */
    uint8_t len;		/* Length of the URI*/
    uint8_t rt[10];		/* Resource type attribute */
    uint8_t iff[10];	/* Interface Description 'if' */
    uint8_t sz;			/* Maximum size estimate attribute */
    uint8_t ct;			/* Content-format attribute*/
    uint8_t is_observe; /* Observe attribute */
  } key_uri_t;
  
#endif
