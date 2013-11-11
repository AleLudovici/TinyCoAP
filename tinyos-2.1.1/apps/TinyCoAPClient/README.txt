README for TinyCoAPClient
Author/Contact: alessandro.ludovici@entel.upc.edu

To build, add the 'blip' and 'tinycoap' make extra.  IE,

$ make <platform> blip tinycoap

Description of TinyCoAPClient:

TinyCoAPClient is an application that acts as a CoAP Client.
It is compliant with the coap-draft-12, coap-observer-7 and RFC 6990
This version shows the main functionalities of CoAP. 
TinyCoAPClient sends a GET request to the .well-known/core interface of the TinyCoAPServer.
Once it receives an answer, TinyCoAPClient sends a GET observe request to the URI of the resource indicated in the answer.
The updated received after establishing the observe relationship are printed using the printf library if TinyOS.

Set-up variable can be defined in the MAKEFILE. The variable defined as follows: 

CFLAGS += -DMAX_PAYLOAD  		------> The maximum payload that can a CoAP packet can have
CFLAGS += -DMAX_OPT_DATA		------> The maximum length that can a CoAP option can have
CFLAGS += -DMAX_OPT			------> The maximum number of CoAP option that can be allocated
CFLAGS += -DMAX_COAP_CONNECTIONS	------> The maximum number of coap_connection_t structure that can be allocated. These are used for RTX purposes.
CFLAGS += -DMAX_PDUS   	                ------> The maximum number of CoAP PDU that can be allocated
CFLAGS += -DWAITING_LIST 		------> The maximum length of the waiting list. This is used to store coap_connection_t elements for RTX purposes.
CFLAGS += -DMAX_PACKET_LEN   		------> The maximum length that can a CoAP packet can have (Header+Option+Payload)
CFLAGS += -DMAX_URI_LEN      		------> The maximum length that resource URI can have

Please refer to the comments inside the code for more information.

Known bugs/limitations:
It does not implement the CoAP Block option
