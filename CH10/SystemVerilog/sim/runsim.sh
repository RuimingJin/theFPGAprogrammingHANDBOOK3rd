rm -rf xsim*
xvlog -sv ../hdl/dht11_axi_lite.sv ../tb/tb_dht11_axi_lite.sv
xelab --timescale 1ns/10ps --debug all -L xpm tb_dht11_axi_lite
xsim -gui work.tb_dht11_axi_lite
