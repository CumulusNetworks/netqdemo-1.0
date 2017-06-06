#!/bin/csh

cli -c 'configure; set interfaces ge-0/0/1 unit 0; set interfaces ge-0/0/2 unit 0; set interfaces ge-0/0/3 unit 0; edit protocols lldp; set interface all; commit'
