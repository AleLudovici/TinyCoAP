#include "./include/coap_general.h"

configuration CoapClientC {
    provides interface CoapClient;
    provides interface CoapPdu;
} implementation {

    components CoapClientP;
    components IPDispatchC, MainC, LedsC;

    components new CoapPduC(MAX_PDUS);
  
    CoapClient = CoapClientP;

    CoapClientP.CoapPdu -> CoapPduC;

    CoapPdu = CoapPduC;

    CoapClientP.Boot -> MainC;
    CoapClientP.RadioControl -> IPDispatchC;
    
    CoapClientP.Leds -> LedsC;

    components new UdpSocketC();
    CoapClientP.UdpClient -> UdpSocketC;

	components new VirtualizeTimerC(TMilli, WAITING_LIST) as Timers;
    components new TimerMilliC() as AckSourceTimer;
	
    Timers.TimerFrom->AckSourceTimer;

    CoapClientP.Timers->Timers;

#if !defined(INCOMING_QUEUE) 
    #define INCOMING_QUEUE 10
#endif

    components new QueueC(coap_pdu_t *,INCOMING_QUEUE) as IncomingQueue;
    CoapClientP.IncomingQueue -> IncomingQueue;

    components new PoolC(coap_connection_t,MAX_COAP_CONNECTIONS) as CoapConnectionPool;
    CoapClientP.CoapConnectionPool -> CoapConnectionPool;

    components new CoapListC(WAITING_LIST) as WaitingList;
    CoapClientP.WaitingList -> WaitingList;

    components RandomC;
    CoapClientP.Random -> RandomC;

}
