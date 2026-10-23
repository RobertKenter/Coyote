##
## QSFP 0's partner cage: the second port of the same DCMAC (N_NET_PORTS = 2), GTM bank 210
##

# Reference clock: QSFP 0's (GTM bank 209), which both cages share

# Transceiver connections, lane i on channel i of the bank
set_property    PACKAGE_PIN AA67    [get_ports  {gt1_rxp_in[0]} ];
set_property    PACKAGE_PIN AA64    [get_ports  {gt1_rxp_in[1]} ];
set_property    PACKAGE_PIN W67     [get_ports  {gt1_rxp_in[2]} ];
set_property    PACKAGE_PIN W64     [get_ports  {gt1_rxp_in[3]} ];

set_property    PACKAGE_PIN AC61    [get_ports  {gt1_txp_out[0]} ];
set_property    PACKAGE_PIN AC58    [get_ports  {gt1_txp_out[1]} ];
set_property    PACKAGE_PIN AA61    [get_ports  {gt1_txp_out[2]} ];
set_property    PACKAGE_PIN AA58    [get_ports  {gt1_txp_out[3]} ];
