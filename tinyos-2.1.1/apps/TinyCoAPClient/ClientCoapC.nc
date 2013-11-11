configuration ClientCoapC {
} implementation {
    components MainC, CoapClientC;
    components ClientCoapP;
	
	ClientCoapP.Boot -> MainC;
    ClientCoapP.CoapClient -> CoapClientC;
    ClientCoapP.CoapPdu -> CoapClientC.CoapPdu;
	
	components new TimerMilliC() as Timer0;
	ClientCoapP.Timer0 -> Timer0;
	
	components RandomC;
    ClientCoapP.Random -> RandomC;
}
