create_clock -period 5 -name sys_clk [get_ports clk]



set_false_path -from [get_ports rst]
set_false_path -from [get_ports rxd]
set_false_path -from [get_ports prescale[*]]

set_false_path -to [get_ports txd]