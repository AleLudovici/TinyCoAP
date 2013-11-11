TinyCoAP implements the CoAP protocol (draft-13) in TinyOS. It is written in nesC and adopt the programming model of TinyOS.
TinyCoAP is part of the research paper "TinyCoAP: A Novel Constrained Application Protocol (CoAP) Implementation for Embedding RESTful Web Services in Wireless Sensor Networks Based on TinyOS", which can be found at http://www.mdpi.com/2224-2708/2/2/288

HOW TO USE IT:
Copy the tinycoap.extra file in support/make

build syntax:
make <platform> blip tinycoap 

It has been tested with telosb so far.
Tinycoap provide a Coap client and server. These are located at apps/TinyCoAPServer and apps/TinyCoAPClient.

Please find further instruction in README files in apps/TinyCoAPServer and apps/TinyCoAPClient

KNOWN LIMITATIONS:
TinyCoAP is designed to work with TinyOS 2.1.1. It has been not tested with TinyOS 2.1.2

It does not work with BLIP 2.0