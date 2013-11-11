configuration CoapServerC {
    provides interface CoapServer;
    provides interface CoapPdu;
    uses interface CoapResource[uint8_t id];
} implementation {

    components CoapServerP;
    components IPDispatchC, MainC;
  
    CoapServer = CoapServerP;

    CoapServerP.Boot -> MainC;
    CoapServerP.RadioControl -> IPDispatchC;

    components new UdpSocketC();
    CoapServerP.UdpServer -> UdpSocketC;

    components new CoapPduC(MAX_PDUS);
    CoapServerP.CoapPdu -> CoapPduC;

    CoapPdu = CoapPduC;

    components new VirtualizeTimerC(TMilli,WAITING_LIST) as Timers;
    components new TimerMilliC() as AckSourceTimer;
	
    Timers.TimerFrom->AckSourceTimer;

    CoapServerP.Timers->Timers;
    
    CoapServerP.CoapResource = CoapResource;

#if !defined(INCOMING_QUEUE) 
    #define INCOMING_QUEUE 10
#endif
    
    components new QueueC(coap_pdu_t *,INCOMING_QUEUE) as IncomingQueue;
    CoapServerP.IncomingQueue -> IncomingQueue;

#if !defined(PROCESSING_QUEUE) 
    #define PROCESSING_QUEUE 10
#endif
    
    components new QueueC(coap_pdu_t *, PROCESSING_QUEUE) as ProcessingQueue;
    CoapServerP.ProcessingQueue -> ProcessingQueue;

    components new PoolC(coap_connection_t, MAX_COAP_CONNECTIONS) as CoapConnectionPool;
    CoapServerP.CoapConnectionPool -> CoapConnectionPool;

    components new CoapListC(WAITING_LIST) as WaitingList;
    CoapServerP.WaitingList -> WaitingList;

    components RandomC;
    CoapServerP.Random -> RandomC;
}
