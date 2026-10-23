##
## The left-hand cages: the other DCMAC's two ports (N_NET_PORTS = 4), GTM banks 111 (port 2) and
## 112 (port 3); AMD's AVED pin list (impl.pins.xdc) calls them qsfp3 and qsfp2
##

# Reference clock (322 MHz), which both cages share: bank 111's GTM_REFCLKP0 (AVED's
# qsfp2_322mhz_clk_p)
set_property    PACKAGE_PIN AL17    [get_ports  gt2_refclk_p];
create_clock -period 3.103 -name gt2_refclk_p [get_ports gt2_refclk_p];

# Transceiver connections, lane i on channel i of the bank
set_property    PACKAGE_PIN AA3     [get_ports  {gt2_rxp_in[0]} ];
set_property    PACKAGE_PIN AA6     [get_ports  {gt2_rxp_in[1]} ];
set_property    PACKAGE_PIN W3      [get_ports  {gt2_rxp_in[2]} ];
set_property    PACKAGE_PIN W6      [get_ports  {gt2_rxp_in[3]} ];

set_property    PACKAGE_PIN AA9     [get_ports  {gt2_txp_out[0]} ];
set_property    PACKAGE_PIN AA12    [get_ports  {gt2_txp_out[1]} ];
set_property    PACKAGE_PIN W9      [get_ports  {gt2_txp_out[2]} ];
set_property    PACKAGE_PIN W12     [get_ports  {gt2_txp_out[3]} ];

set_property    PACKAGE_PIN U3      [get_ports  {gt3_rxp_in[0]} ];
set_property    PACKAGE_PIN U6      [get_ports  {gt3_rxp_in[1]} ];
set_property    PACKAGE_PIN R3      [get_ports  {gt3_rxp_in[2]} ];
set_property    PACKAGE_PIN R6      [get_ports  {gt3_rxp_in[3]} ];

set_property    PACKAGE_PIN U9      [get_ports  {gt3_txp_out[0]} ];
set_property    PACKAGE_PIN U12     [get_ports  {gt3_txp_out[1]} ];
set_property    PACKAGE_PIN R9      [get_ports  {gt3_txp_out[2]} ];
set_property    PACKAGE_PIN R12     [get_ports  {gt3_txp_out[3]} ];
