`timescale 1ns/1ps
//============================================================================
// adt7420_axil
//----------------------------------------------------------------------------
// AXI4-Lite wrapper around adt7420_temp_if.  Exposes the current (instantaneous)
// and 16-sample-averaged ADT7420 temperatures, plus status, as read registers.
// The sensor logic runs on the AXI clock (single clock domain, no CDC).
//
// Register map (byte offsets, 32-bit registers, read-only):
//   0x00  TEMP_INST  signed 32-bit, sign-extended.  degC = value / 128.0
//   0x04  TEMP_AVG   signed 32-bit, sign-extended.  degC = value / 128.0
//   0x08  STATUS     [0]     busy   (transaction in progress)
//                    [1]     error  (last I2C transaction was NACKed)
//                    [31:16] sample counter (increments per new measurement)
//   0x0C  ID         0x00007420 (ADT7420 part number, for probing)
//
// Writes are accepted and answered OKAY (there are no writable registers).
//============================================================================
module adt7420_axil_wrapper #(
    parameter CLK_FREQ_HZ         = 100_000_000, // = AXI clock
    parameter I2C_FREQ_HZ         = 100_000,
    parameter SAMPLE_HZ           = 4,
    parameter DEV_ADDR            = 7'h4B,
    parameter AVG_N               = 16,
    parameter C_S_AXI_ADDR_WIDTH  = 16
)(
    // AXI4-Lite slave
    input                          s_axi_aclk,
    input                          s_axi_aresetn,

    input [C_S_AXI_ADDR_WIDTH-1:0] s_axi_awaddr,
    input                          s_axi_awvalid,
    output                         s_axi_awready,
    input [31:0]                   s_axi_wdata,
    input [3:0]                    s_axi_wstrb,
    input                          s_axi_wvalid,
    output                         s_axi_wready,
    output [1:0]                   s_axi_bresp,
    output                         s_axi_bvalid,
    input                          s_axi_bready,

    input [C_S_AXI_ADDR_WIDTH-1:0] s_axi_araddr,
    input                          s_axi_arvalid,
    output                         s_axi_arready,
    output [31:0]                  s_axi_rdata,
    output [1:0]                   s_axi_rresp,
    output                         s_axi_rvalid,
    input                          s_axi_rready,

    output                         temp_inst_valid,
    output [15:0]                  temp_inst,
    input                          fx_inst_valid,
    input [15:0]                   fx_inst,
    input                          fh_inst_valid,
    input [15:0]                   fh_inst,

    // I2C open-drain bus (to external IOBUFs)
    input                          scl_i,
    output                         scl_o,
    output                         scl_t,
    input                          sda_i,
    output                         sda_o,
    output                         sda_t
  );

  adt7420_axil
    #
    (
     .CLK_FREQ_HZ         (CLK_FREQ_HZ),
     .I2C_FREQ_HZ         (I2C_FREQ_HZ),
     .SAMPLE_HZ           (SAMPLE_HZ),
     .DEV_ADDR            (DEV_ADDR),
     .AVG_N               (AVG_N),
     .C_S_AXI_ADDR_WIDTH  (C_S_AXI_ADDR_WIDTH)
     )
  adt7420_axil
    (
     // AXI4-Lite slave
     .s_axi_aclk    (s_axi_aclk),
     .s_axi_aresetn (s_axi_aresetn),

     .s_axi_awaddr  (s_axi_awaddr),
     .s_axi_awvalid (s_axi_awvalid),
     .s_axi_awready (s_axi_awready),
     .s_axi_wdata   (s_axi_wdata),
     .s_axi_wstrb   (s_axi_wstrb),
     .s_axi_wvalid  (s_axi_wvalid),
     .s_axi_wready  (s_axi_wready),
     .s_axi_bresp   (s_axi_bresp),
     .s_axi_bvalid  (s_axi_bvalid),
     .s_axi_bready  (s_axi_bready),

     .s_axi_araddr  (s_axi_araddr),
     .s_axi_arvalid (s_axi_arvalid),
     .s_axi_arready (s_axi_arready),
     .s_axi_rdata   (s_axi_rdata),
     .s_axi_rresp   (s_axi_rresp),
     .s_axi_rvalid  (s_axi_rvalid),
     .s_axi_rready  (s_axi_rready),

     .temp_inst_valid(temp_inst_valid),
     .temp_inst      (temp_inst),
     .fx_inst_valid  (fx_inst_valid),
     .fx_inst        (fx_inst),
     .fh_inst_valid  (fh_inst_valid),
     .fh_inst        (fh_inst),

     // I2C open-drain bus (to external IOBUFs)
     .scl_i         (scl_i),
     .scl_o         (scl_o),
     .scl_t         (scl_t),
     .sda_i         (sda_i),
     .sda_o         (sda_o),
     .sda_t         (sda_t)
     );
endmodule
