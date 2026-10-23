##
## Two network ports: the DCMAC status register (shell_slave DCMAC_STATUS_REG) samples bits from
## the DCMAC's and the GTs' clocks; they are quasi-static and synchronised there
##

set_false_path -to [get_cells -hier -filter {NAME =~ inst_shell/inst_shell_slave/dcmac_status_s0_reg*}]
