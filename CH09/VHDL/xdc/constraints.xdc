set_max_delay -from [get_pins {hw_i/rst_ps8_0_96M/U0/ACTIVE_LOW_PR_OUT_DFF[0].FDRE_PER_N/C}] -to [get_pins {hw_i/audio/aic3104_*_0/inst/rst_sync_reg[0]/D}] 5.0
set_max_delay -from [get_pins {hw_i/rst_ps8_0_96M/U0/ACTIVE_LOW_BSR_OUT_DFF[0].FDRE_BSR_N/C}] -to [get_pins {hw_i/audio/aic3104_dma_0/inst/rst_sync_reg[0]/D}] 5.0
set_max_delay -from [get_pins {hw_i/audio/aic3104_*_0/inst/rx_dly_reg[?]/C}] -to [get_pins {hw_i/audio/aic3104_*_0/inst/rx_dly_meta_reg[?]/D}] 5.0

set_max_delay -from [get_pins {hw_i/audio/aic3104_*_0/inst/rx_ctrl_reg[0]/C}] -to [get_pins {hw_i/audio/aic3104_*_0/inst/rx_ctrl_sync_reg[0]/D}] 5.0
set_max_delay -from [get_pins hw_i/audio/aic3104_dma_0/inst/u_axi_dma_writer/busy_r_reg/C] -to [get_pins {hw_i/audio/aic3104_dma_0/inst/rx_en_reg[0]/D}] 5.0
