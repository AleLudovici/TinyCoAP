#include "resources/resources.h"

configuration CoapExampleServerC {
} implementation {
    components MainC;
    components CoapExampleServerP;
    components CoapServerC;

    CoapExampleServerP.Boot -> MainC;
    CoapExampleServerP.CoapServer -> CoapServerC;
    CoapExampleServerP.CoapPdu -> CoapServerC.CoapPdu;
   
    components TestResourceC;
    TestResourceC.CoapPdu ->CoapServerC.CoapPdu;
    CoapServerC.CoapResource[KEY_TEST] -> TestResourceC. CoapResource; 
}
