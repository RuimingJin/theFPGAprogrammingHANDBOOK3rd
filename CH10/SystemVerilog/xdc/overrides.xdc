## Grove PL

set_property PACKAGE_PIN AD15 [get_ports {iic_display_io_scl_io}]
set_property PACKAGE_PIN AD14 [get_ports {iic_display_io_sda_io}]
set_property IOSTANDARD LVCMOS33 [get_ports {iic_display*}]

# PMOD override
set_property PACKAGE_PIN J10 [get_ports {IIC_sda_io}]
set_property PACKAGE_PIN J11 [get_ports {IIC_scl_io}]
set_property IOSTANDARD LVCMOS33 [get_ports IIC*]
