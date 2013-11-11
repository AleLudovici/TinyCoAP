README for TinyCoAPServer
Author/Contact: alessandro.ludovici@entel.upc.edu

To build, add the 'blip' and 'tinycoap' make extra.  IE,

$ make <platform> blip tinycoap

Description of TinyCoAPServer:

TinyCoAPServer is an application that acts as a CoAP Server.
It is compliant with the coap-draft-12, coap-observer-7 and RFC 6990
The resources exposed by TinyCoAPServer are defined in resource.h
This version define a 'test' resource. Client can perform simple GET piggy-backed requests or can observe the resource.
The .well-known/core interface is implemented in CoAPServerP.nc (tos/lib/net/TinyCoAP)
TinyCoAPServer uses linked lists allocated trough the PoolC component.
Set-up variable can be defined in the MAKEFILE. The variable defined as follows: 

CFLAGS += -DMAX_PAYLOAD  		------> The maximum payload that can a CoAP packet can have
CFLAGS += -DMAX_OPT_DATA		------> The maximum length that can a CoAP option can have
CFLAGS += -DMAX_OPT			------> The maximum number of CoAP option that can be allocated
CFLAGS += -DMAX_COAP_CONNECTIONS	------> The maximum number of coap_connection_t structure that can be allocated. These are used for RTX purpose.
CFLAGS += -DMAX_PDUS   	                ------> The maximum number of CoAP PDU that can be allocated
CFLAGS += -DWAITING_LIST 		------> The maximum length of the waiting list. This is used to store coap_connection_t elements for RTX purpose and separated_responses
CFLAGS += -DMAX_PACKET_LEN   		------> The maximum length that can a CoAP packet can have (Header+Option+Payload)
CFLAGS += -DMAX_URI_LEN      		------> The maximum length that resource URI can have
CFLAGS += -DMAX_OBSERVERS      		------> The maximum nummber of observers

Please refer to the comments inside the code for more information.

Known bugs/limitations:
It does not implement the CoAP Block option
