`timescale 1ns/10ps
module adt7420_i2c_mod_wrapper
  #
  (
   parameter  DEVICE_ID    = "TEMP",
   parameter  SMOOTHING    = 16,
   parameter  INTERVAL     = 1000000000,
   parameter  CLK_PER      = 10
   )
  (
   input         s_axi_aclk,
   input         s_axi_aresetn,
   input [21:0]  s_axi_awaddr,
   input         s_axi_awvalid,
   output        s_axi_awready,
   input [31:0]  s_axi_wdata,
   input [3:0]   s_axi_wstrb,
   input         s_axi_wvalid,
   output        s_axi_wready,
   output [1:0]  s_axi_bresp,
   output        s_axi_bvalid,
   input         s_axi_bready,
   input [21:0]  s_axi_araddr,
   input         s_axi_arvalid,
   output        s_axi_arready,
   output [31:0] s_axi_rdata,
   output [1:0]  s_axi_rresp,
   output        s_axi_rvalid,
   input         s_axi_rready,

   // Temperature Sensor Interface
   input         TMP_SCL_i,
   output        TMP_SCL_o,
   output        TMP_SCL_t,
   input         TMP_SDA_i,
   output        TMP_SDA_o,
   output        TMP_SDA_t,
   inout         TMP_INT,
   inout         TMP_CT,

   output        fix_temp_tvalid,
   output [15:0] fix_temp_tdata,

   input         flt_temp_tvalid,
   input [15:0]  flt_temp_tdata
   );

  adt7420_i2c_mod
    #
    (
     .DEVICE_ID        (DEVICE_ID),
     .SMOOTHING        (SMOOTHING),
     .INTERVAL         (INTERVAL),
     .CLK_PER          (CLK_PER)
     )
  adt7420_i2c_mod
    (
     .s_axi_aclk       (s_axi_aclk),
     .s_axi_aresetn    (s_axi_aresetn),
     .s_axi_awaddr     (s_axi_awaddr),
     .s_axi_awvalid    (s_axi_awvalid),
     .s_axi_awready    (s_axi_awready),
     .s_axi_wdata      (s_axi_wdata),
     .s_axi_wstrb      (s_axi_wstrb),
     .s_axi_wvalid     (s_axi_wvalid),
     .s_axi_wready     (s_axi_wready),
     .s_axi_bresp      (s_axi_bresp),
     .s_axi_bvalid     (s_axi_bvalid),
     .s_axi_bready     (s_axi_bready),
     .s_axi_araddr     (s_axi_araddr),
     .s_axi_arvalid    (s_axi_arvalid),
     .s_axi_arready    (s_axi_arready),
     .s_axi_rdata      (s_axi_rdata),
     .s_axi_rresp      (s_axi_rresp),
     .s_axi_rvalid     (s_axi_rvalid),
     .s_axi_rready     (s_axi_rready),
     .TMP_SCL_i        (TMP_SCL_i),
     .TMP_SCL_o        (TMP_SCL_o),
     .TMP_SCL_t        (TMP_SCL_t),
     .TMP_SDA_i        (TMP_SDA_i),
     .TMP_SDA_o        (TMP_SDA_o),
     .TMP_SDA_t        (TMP_SDA_t),
     .TMP_INT          (TMP_INT),
     .TMP_CT           (TMP_CT),

     .fix_temp_tvalid  (fix_temp_tvalid),
     .fix_temp_tdata   (fix_temp_tdata),

     .flt_temp_tvalid  (flt_temp_tvalid),
     .flt_temp_tdata   (flt_temp_tdata)
     );
endmodule
