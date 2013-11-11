configuration TestResourceC {
    provides interface CoapResource;
	uses interface CoapPdu;
} implementation {
	
	components TestResourceP;
	CoapResource = TestResourceP;
   
    components new CoapListC(MAX_OBSERVERS) as ObserversCtrList;
    TestResourceP.ObserversCtrList -> ObserversCtrList;
   
    components new PoolC(coap_observe_t, MAX_OBSERVERS) as addrPool;
    TestResourceP.addrPool-> addrPool;
    
    TestResourceP.CoapPdu = CoapPdu;
        
	components new TimerMilliC() as Timer0;
	TestResourceP.Timer0 -> Timer0;
}
