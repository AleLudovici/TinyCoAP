COMPONENT=ClientCoapC

CFLAGS += -DCC2420_DEF_CHANNEL=13
CFLAGS += -DCC2420_DEF_RFPOWER=4

# disables support for the AM stack, which somewhat reduces code size
# and compresses packet formats.  If you want to use other tinyos
# protocols which are AM-based, you should not include this.
CFLAGS += -DIEEE154FRAMES_ENABLED
PFLAGS +=-I./resources

CFLAGS += -DMAX_PAYLOAD=30
CFLAGS += -DMAX_OPT_DATA=15
CFLAGS += -DMAX_OPT=10
CFLAGS += -DMAX_COAP_CONNECTIONS=10
CFLAGS += -DMAX_PDUS=6
CFLAGS += -DWAITING_LIST=6
CFLAGS += -DMAX_PACKET_LEN=80
CFLAGS += -DMAX_URI_LEN=20

CFLAGS += -I$(TOSDIR)/lib/printf

include $(MAKERULES)

