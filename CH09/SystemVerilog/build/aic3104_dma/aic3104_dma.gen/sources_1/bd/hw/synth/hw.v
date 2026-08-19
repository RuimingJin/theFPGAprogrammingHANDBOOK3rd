//Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
//Copyright 2022-2025 Advanced Micro Devices, Inc. All Rights Reserved.
//--------------------------------------------------------------------------------
//Tool Version: Vivado v.2025.2 (win64) Build 6299465 Fri Nov 14 19:35:11 GMT 2025
//Date        : Tue Aug 18 07:36:55 2026
//Host        : RjMs running 64-bit major release  (build 9200)
//Command     : generate_target hw.bd
//Design      : hw
//Purpose     : IP block netlist
//--------------------------------------------------------------------------------
`timescale 1 ps / 1 ps

module audio_imp_FTOWPL
   (AIC_lrclk_o,
    AIC_mclk_o,
    AIC_nRST,
    AIC_sclk_o,
    AIC_sdata_i,
    S_AXI2_araddr,
    S_AXI2_arready,
    S_AXI2_arvalid,
    S_AXI2_awaddr,
    S_AXI2_awready,
    S_AXI2_awvalid,
    S_AXI2_bready,
    S_AXI2_bresp,
    S_AXI2_bvalid,
    S_AXI2_rdata,
    S_AXI2_rready,
    S_AXI2_rresp,
    S_AXI2_rvalid,
    S_AXI2_wdata,
    S_AXI2_wready,
    S_AXI2_wstrb,
    S_AXI2_wvalid,
    S_AXI_araddr,
    S_AXI_arready,
    S_AXI_arvalid,
    S_AXI_awaddr,
    S_AXI_awready,
    S_AXI_awvalid,
    S_AXI_bready,
    S_AXI_bresp,
    S_AXI_bvalid,
    S_AXI_rdata,
    S_AXI_rready,
    S_AXI_rresp,
    S_AXI_rvalid,
    S_AXI_wdata,
    S_AXI_wready,
    S_AXI_wstrb,
    S_AXI_wvalid,
    i2c_aic_scl_i,
    i2c_aic_scl_o,
    i2c_aic_scl_t,
    i2c_aic_sda_i,
    i2c_aic_sda_o,
    i2c_aic_sda_t,
    i2s_sdata_o,
    iic2intc_irpt,
    m_axi_araddr,
    m_axi_arburst,
    m_axi_arcache,
    m_axi_arid,
    m_axi_arlen,
    m_axi_arlock,
    m_axi_arprot,
    m_axi_arready,
    m_axi_arsize,
    m_axi_arvalid,
    m_axi_awaddr,
    m_axi_awburst,
    m_axi_awcache,
    m_axi_awid,
    m_axi_awlen,
    m_axi_awlock,
    m_axi_awprot,
    m_axi_awready,
    m_axi_awsize,
    m_axi_awvalid,
    m_axi_bid,
    m_axi_bready,
    m_axi_bresp,
    m_axi_bvalid,
    m_axi_rdata,
    m_axi_rlast,
    m_axi_rready,
    m_axi_rresp,
    m_axi_rvalid,
    m_axi_wdata,
    m_axi_wlast,
    m_axi_wready,
    m_axi_wstrb,
    m_axi_wvalid,
    resetn,
    s_axi1_araddr,
    s_axi1_arready,
    s_axi1_arvalid,
    s_axi1_awaddr,
    s_axi1_awready,
    s_axi1_awvalid,
    s_axi1_bready,
    s_axi1_bresp,
    s_axi1_bvalid,
    s_axi1_rdata,
    s_axi1_rready,
    s_axi1_rresp,
    s_axi1_rvalid,
    s_axi1_wdata,
    s_axi1_wready,
    s_axi1_wstrb,
    s_axi1_wvalid,
    s_axi_aclk,
    s_axi_aresetn);
  output AIC_lrclk_o;
  output AIC_mclk_o;
  output [0:0]AIC_nRST;
  output AIC_sclk_o;
  input AIC_sdata_i;
  input [8:0]S_AXI2_araddr;
  output S_AXI2_arready;
  input S_AXI2_arvalid;
  input [8:0]S_AXI2_awaddr;
  output S_AXI2_awready;
  input S_AXI2_awvalid;
  input S_AXI2_bready;
  output [1:0]S_AXI2_bresp;
  output S_AXI2_bvalid;
  output [31:0]S_AXI2_rdata;
  input S_AXI2_rready;
  output [1:0]S_AXI2_rresp;
  output S_AXI2_rvalid;
  input [31:0]S_AXI2_wdata;
  output S_AXI2_wready;
  input [3:0]S_AXI2_wstrb;
  input S_AXI2_wvalid;
  input [8:0]S_AXI_araddr;
  output S_AXI_arready;
  input S_AXI_arvalid;
  input [8:0]S_AXI_awaddr;
  output S_AXI_awready;
  input S_AXI_awvalid;
  input S_AXI_bready;
  output [1:0]S_AXI_bresp;
  output S_AXI_bvalid;
  output [31:0]S_AXI_rdata;
  input S_AXI_rready;
  output [1:0]S_AXI_rresp;
  output S_AXI_rvalid;
  input [31:0]S_AXI_wdata;
  output S_AXI_wready;
  input [3:0]S_AXI_wstrb;
  input S_AXI_wvalid;
  input i2c_aic_scl_i;
  output i2c_aic_scl_o;
  output i2c_aic_scl_t;
  input i2c_aic_sda_i;
  output i2c_aic_sda_o;
  output i2c_aic_sda_t;
  output i2s_sdata_o;
  output iic2intc_irpt;
  output [39:0]m_axi_araddr;
  output [1:0]m_axi_arburst;
  output [3:0]m_axi_arcache;
  output [5:0]m_axi_arid;
  output [7:0]m_axi_arlen;
  output m_axi_arlock;
  output [2:0]m_axi_arprot;
  input m_axi_arready;
  output [2:0]m_axi_arsize;
  output m_axi_arvalid;
  output [39:0]m_axi_awaddr;
  output [1:0]m_axi_awburst;
  output [3:0]m_axi_awcache;
  output [5:0]m_axi_awid;
  output [7:0]m_axi_awlen;
  output m_axi_awlock;
  output [2:0]m_axi_awprot;
  input m_axi_awready;
  output [2:0]m_axi_awsize;
  output m_axi_awvalid;
  input [5:0]m_axi_bid;
  output m_axi_bready;
  input [1:0]m_axi_bresp;
  input m_axi_bvalid;
  input [31:0]m_axi_rdata;
  input m_axi_rlast;
  output m_axi_rready;
  input [1:0]m_axi_rresp;
  input m_axi_rvalid;
  output [31:0]m_axi_wdata;
  output m_axi_wlast;
  input m_axi_wready;
  output [3:0]m_axi_wstrb;
  output m_axi_wvalid;
  input resetn;
  input [21:0]s_axi1_araddr;
  output s_axi1_arready;
  input s_axi1_arvalid;
  input [21:0]s_axi1_awaddr;
  output s_axi1_awready;
  input s_axi1_awvalid;
  input s_axi1_bready;
  output [1:0]s_axi1_bresp;
  output s_axi1_bvalid;
  output [31:0]s_axi1_rdata;
  input s_axi1_rready;
  output [1:0]s_axi1_rresp;
  output s_axi1_rvalid;
  input [31:0]s_axi1_wdata;
  output s_axi1_wready;
  input [3:0]s_axi1_wstrb;
  input s_axi1_wvalid;
  input s_axi_aclk;
  input s_axi_aresetn;

  wire AIC_lrclk_o;
  wire AIC_mclk_o;
  wire [0:0]AIC_nRST;
  wire AIC_sclk_o;
  wire AIC_sdata_i;
  wire [8:0]S_AXI2_araddr;
  wire S_AXI2_arready;
  wire S_AXI2_arvalid;
  wire [8:0]S_AXI2_awaddr;
  wire S_AXI2_awready;
  wire S_AXI2_awvalid;
  wire S_AXI2_bready;
  wire [1:0]S_AXI2_bresp;
  wire S_AXI2_bvalid;
  wire [31:0]S_AXI2_rdata;
  wire S_AXI2_rready;
  wire [1:0]S_AXI2_rresp;
  wire S_AXI2_rvalid;
  wire [31:0]S_AXI2_wdata;
  wire S_AXI2_wready;
  wire [3:0]S_AXI2_wstrb;
  wire S_AXI2_wvalid;
  wire [8:0]S_AXI_araddr;
  wire S_AXI_arready;
  wire S_AXI_arvalid;
  wire [8:0]S_AXI_awaddr;
  wire S_AXI_awready;
  wire S_AXI_awvalid;
  wire S_AXI_bready;
  wire [1:0]S_AXI_bresp;
  wire S_AXI_bvalid;
  wire [31:0]S_AXI_rdata;
  wire S_AXI_rready;
  wire [1:0]S_AXI_rresp;
  wire S_AXI_rvalid;
  wire [31:0]S_AXI_wdata;
  wire S_AXI_wready;
  wire [3:0]S_AXI_wstrb;
  wire S_AXI_wvalid;
  wire i2c_aic_scl_i;
  wire i2c_aic_scl_o;
  wire i2c_aic_scl_t;
  wire i2c_aic_sda_i;
  wire i2c_aic_sda_o;
  wire i2c_aic_sda_t;
  wire i2s_sdata_o;
  wire iic2intc_irpt;
  wire [39:0]m_axi_araddr;
  wire [1:0]m_axi_arburst;
  wire [3:0]m_axi_arcache;
  wire [5:0]m_axi_arid;
  wire [7:0]m_axi_arlen;
  wire m_axi_arlock;
  wire [2:0]m_axi_arprot;
  wire m_axi_arready;
  wire [2:0]m_axi_arsize;
  wire m_axi_arvalid;
  wire [39:0]m_axi_awaddr;
  wire [1:0]m_axi_awburst;
  wire [3:0]m_axi_awcache;
  wire [5:0]m_axi_awid;
  wire [7:0]m_axi_awlen;
  wire m_axi_awlock;
  wire [2:0]m_axi_awprot;
  wire m_axi_awready;
  wire [2:0]m_axi_awsize;
  wire m_axi_awvalid;
  wire [5:0]m_axi_bid;
  wire m_axi_bready;
  wire [1:0]m_axi_bresp;
  wire m_axi_bvalid;
  wire [31:0]m_axi_rdata;
  wire m_axi_rlast;
  wire m_axi_rready;
  wire [1:0]m_axi_rresp;
  wire m_axi_rvalid;
  wire [31:0]m_axi_wdata;
  wire m_axi_wlast;
  wire m_axi_wready;
  wire [3:0]m_axi_wstrb;
  wire m_axi_wvalid;
  wire resetn;
  wire [21:0]s_axi1_araddr;
  wire s_axi1_arready;
  wire s_axi1_arvalid;
  wire [21:0]s_axi1_awaddr;
  wire s_axi1_awready;
  wire s_axi1_awvalid;
  wire s_axi1_bready;
  wire [1:0]s_axi1_bresp;
  wire s_axi1_bvalid;
  wire [31:0]s_axi1_rdata;
  wire s_axi1_rready;
  wire [1:0]s_axi1_rresp;
  wire s_axi1_rvalid;
  wire [31:0]s_axi1_wdata;
  wire s_axi1_wready;
  wire [3:0]s_axi1_wstrb;
  wire s_axi1_wvalid;
  wire s_axi_aclk;
  wire s_axi_aresetn;

  hw_aic3104_dma_wrapper_0_0 aic3104_dma_wrapper_0
       (.AIC_lrclk_o(AIC_lrclk_o),
        .AIC_mclk_o(AIC_mclk_o),
        .AIC_sclk_o(AIC_sclk_o),
        .i2s_sdata_i(AIC_sdata_i),
        .i2s_sdata_o(i2s_sdata_o),
        .m_axi_araddr(m_axi_araddr),
        .m_axi_arburst(m_axi_arburst),
        .m_axi_arcache(m_axi_arcache),
        .m_axi_arid(m_axi_arid),
        .m_axi_arlen(m_axi_arlen),
        .m_axi_arlock(m_axi_arlock),
        .m_axi_arprot(m_axi_arprot),
        .m_axi_arready(m_axi_arready),
        .m_axi_arsize(m_axi_arsize),
        .m_axi_arvalid(m_axi_arvalid),
        .m_axi_awaddr(m_axi_awaddr),
        .m_axi_awburst(m_axi_awburst),
        .m_axi_awcache(m_axi_awcache),
        .m_axi_awid(m_axi_awid),
        .m_axi_awlen(m_axi_awlen),
        .m_axi_awlock(m_axi_awlock),
        .m_axi_awprot(m_axi_awprot),
        .m_axi_awready(m_axi_awready),
        .m_axi_awsize(m_axi_awsize),
        .m_axi_awvalid(m_axi_awvalid),
        .m_axi_bid(m_axi_bid),
        .m_axi_bready(m_axi_bready),
        .m_axi_bresp(m_axi_bresp),
        .m_axi_bvalid(m_axi_bvalid),
        .m_axi_rdata(m_axi_rdata),
        .m_axi_rlast(m_axi_rlast),
        .m_axi_rready(m_axi_rready),
        .m_axi_rresp(m_axi_rresp),
        .m_axi_rvalid(m_axi_rvalid),
        .m_axi_wdata(m_axi_wdata),
        .m_axi_wlast(m_axi_wlast),
        .m_axi_wready(m_axi_wready),
        .m_axi_wstrb(m_axi_wstrb),
        .m_axi_wvalid(m_axi_wvalid),
        .s_axi_aclk(s_axi_aclk),
        .s_axi_araddr(s_axi1_araddr),
        .s_axi_aresetn(s_axi_aresetn),
        .s_axi_arready(s_axi1_arready),
        .s_axi_arvalid(s_axi1_arvalid),
        .s_axi_awaddr(s_axi1_awaddr),
        .s_axi_awready(s_axi1_awready),
        .s_axi_awvalid(s_axi1_awvalid),
        .s_axi_bready(s_axi1_bready),
        .s_axi_bresp(s_axi1_bresp),
        .s_axi_bvalid(s_axi1_bvalid),
        .s_axi_rdata(s_axi1_rdata),
        .s_axi_rready(s_axi1_rready),
        .s_axi_rresp(s_axi1_rresp),
        .s_axi_rvalid(s_axi1_rvalid),
        .s_axi_wdata(s_axi1_wdata),
        .s_axi_wready(s_axi1_wready),
        .s_axi_wstrb(s_axi1_wstrb),
        .s_axi_wvalid(s_axi1_wvalid));
  hw_axi_gpio_0_0 axi_gpio_0
       (.gpio_io_o(AIC_nRST),
        .s_axi_aclk(s_axi_aclk),
        .s_axi_araddr(S_AXI2_araddr),
        .s_axi_aresetn(s_axi_aresetn),
        .s_axi_arready(S_AXI2_arready),
        .s_axi_arvalid(S_AXI2_arvalid),
        .s_axi_awaddr(S_AXI2_awaddr),
        .s_axi_awready(S_AXI2_awready),
        .s_axi_awvalid(S_AXI2_awvalid),
        .s_axi_bready(S_AXI2_bready),
        .s_axi_bresp(S_AXI2_bresp),
        .s_axi_bvalid(S_AXI2_bvalid),
        .s_axi_rdata(S_AXI2_rdata),
        .s_axi_rready(S_AXI2_rready),
        .s_axi_rresp(S_AXI2_rresp),
        .s_axi_rvalid(S_AXI2_rvalid),
        .s_axi_wdata(S_AXI2_wdata),
        .s_axi_wready(S_AXI2_wready),
        .s_axi_wstrb(S_AXI2_wstrb),
        .s_axi_wvalid(S_AXI2_wvalid));
  hw_axi_iic_0_0 axi_iic_0
       (.iic2intc_irpt(iic2intc_irpt),
        .s_axi_aclk(s_axi_aclk),
        .s_axi_araddr(S_AXI_araddr),
        .s_axi_aresetn(s_axi_aresetn),
        .s_axi_arready(S_AXI_arready),
        .s_axi_arvalid(S_AXI_arvalid),
        .s_axi_awaddr(S_AXI_awaddr),
        .s_axi_awready(S_AXI_awready),
        .s_axi_awvalid(S_AXI_awvalid),
        .s_axi_bready(S_AXI_bready),
        .s_axi_bresp(S_AXI_bresp),
        .s_axi_bvalid(S_AXI_bvalid),
        .s_axi_rdata(S_AXI_rdata),
        .s_axi_rready(S_AXI_rready),
        .s_axi_rresp(S_AXI_rresp),
        .s_axi_rvalid(S_AXI_rvalid),
        .s_axi_wdata(S_AXI_wdata),
        .s_axi_wready(S_AXI_wready),
        .s_axi_wstrb(S_AXI_wstrb),
        .s_axi_wvalid(S_AXI_wvalid),
        .scl_i(i2c_aic_scl_i),
        .scl_o(i2c_aic_scl_o),
        .scl_t(i2c_aic_scl_t),
        .sda_i(i2c_aic_sda_i),
        .sda_o(i2c_aic_sda_o),
        .sda_t(i2c_aic_sda_t));
  hw_clk_wiz_0_0 clk_wiz_0
       (.clk_in1(s_axi_aclk),
        .clk_out1(AIC_mclk_o),
        .resetn(resetn));
endmodule

(* CORE_GENERATION_INFO = "hw,IP_Integrator,{x_ipVendor=xilinx.com,x_ipLibrary=BlockDiagram,x_ipName=hw,x_ipVersion=1.00.a,x_ipLanguage=VERILOG,numBlks=8,numReposBlks=7,numNonXlnxBlks=0,numHierBlks=1,maxHierDepth=1,numSysgenBlks=0,numHlsBlks=0,numHdlrefBlks=1,numPkgbdBlks=0,bdsource=USER,synth_mode=Hierarchical}" *) (* HW_HANDOFF = "hw.hwdef" *) 
module hw
   (AIC_lrclk_o,
    AIC_mclk_o,
    AIC_nRST,
    AIC_sclk_o,
    AIC_sdata_i,
    AIC_sdata_o,
    i2c_aic_scl_i,
    i2c_aic_scl_o,
    i2c_aic_scl_t,
    i2c_aic_sda_i,
    i2c_aic_sda_o,
    i2c_aic_sda_t);
  output AIC_lrclk_o;
  (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 CLK.AIC_MCLK_O CLK" *) (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME CLK.AIC_MCLK_O, CLK_DOMAIN hw_clk_wiz_0_0_clk_out1, FREQ_HZ 12289007, FREQ_TOLERANCE_HZ 0, INSERT_VIP 0, PHASE 0.0" *) output AIC_mclk_o;
  output [0:0]AIC_nRST;
  output AIC_sclk_o;
  input AIC_sdata_i;
  output AIC_sdata_o;
  (* X_INTERFACE_INFO = "xilinx.com:interface:iic:1.0 i2c_aic SCL_I" *) (* X_INTERFACE_MODE = "Master" *) input i2c_aic_scl_i;
  (* X_INTERFACE_INFO = "xilinx.com:interface:iic:1.0 i2c_aic SCL_O" *) output i2c_aic_scl_o;
  (* X_INTERFACE_INFO = "xilinx.com:interface:iic:1.0 i2c_aic SCL_T" *) output i2c_aic_scl_t;
  (* X_INTERFACE_INFO = "xilinx.com:interface:iic:1.0 i2c_aic SDA_I" *) input i2c_aic_sda_i;
  (* X_INTERFACE_INFO = "xilinx.com:interface:iic:1.0 i2c_aic SDA_O" *) output i2c_aic_sda_o;
  (* X_INTERFACE_INFO = "xilinx.com:interface:iic:1.0 i2c_aic SDA_T" *) output i2c_aic_sda_t;

  wire AIC_lrclk_o;
  wire AIC_mclk_o;
  wire [0:0]AIC_nRST;
  wire AIC_sclk_o;
  wire AIC_sdata_i;
  wire AIC_sdata_o;
  wire [39:0]audio_m_axi_ARADDR;
  wire [1:0]audio_m_axi_ARBURST;
  wire [3:0]audio_m_axi_ARCACHE;
  wire [5:0]audio_m_axi_ARID;
  wire [7:0]audio_m_axi_ARLEN;
  wire audio_m_axi_ARLOCK;
  wire [2:0]audio_m_axi_ARPROT;
  wire audio_m_axi_ARREADY;
  wire [2:0]audio_m_axi_ARSIZE;
  wire audio_m_axi_ARVALID;
  wire [39:0]audio_m_axi_AWADDR;
  wire [1:0]audio_m_axi_AWBURST;
  wire [3:0]audio_m_axi_AWCACHE;
  wire [5:0]audio_m_axi_AWID;
  wire [7:0]audio_m_axi_AWLEN;
  wire audio_m_axi_AWLOCK;
  wire [2:0]audio_m_axi_AWPROT;
  wire audio_m_axi_AWREADY;
  wire [2:0]audio_m_axi_AWSIZE;
  wire audio_m_axi_AWVALID;
  wire [5:0]audio_m_axi_BID;
  wire audio_m_axi_BREADY;
  wire [1:0]audio_m_axi_BRESP;
  wire audio_m_axi_BVALID;
  wire [31:0]audio_m_axi_RDATA;
  wire audio_m_axi_RLAST;
  wire audio_m_axi_RREADY;
  wire [1:0]audio_m_axi_RRESP;
  wire audio_m_axi_RVALID;
  wire [31:0]audio_m_axi_WDATA;
  wire audio_m_axi_WLAST;
  wire audio_m_axi_WREADY;
  wire [3:0]audio_m_axi_WSTRB;
  wire audio_m_axi_WVALID;
  wire axi_iic_0_iic2intc_irpt;
  wire [21:0]axi_smc_M00_AXI_ARADDR;
  wire axi_smc_M00_AXI_ARREADY;
  wire axi_smc_M00_AXI_ARVALID;
  wire [21:0]axi_smc_M00_AXI_AWADDR;
  wire axi_smc_M00_AXI_AWREADY;
  wire axi_smc_M00_AXI_AWVALID;
  wire axi_smc_M00_AXI_BREADY;
  wire [1:0]axi_smc_M00_AXI_BRESP;
  wire axi_smc_M00_AXI_BVALID;
  wire [31:0]axi_smc_M00_AXI_RDATA;
  wire axi_smc_M00_AXI_RREADY;
  wire [1:0]axi_smc_M00_AXI_RRESP;
  wire axi_smc_M00_AXI_RVALID;
  wire [31:0]axi_smc_M00_AXI_WDATA;
  wire axi_smc_M00_AXI_WREADY;
  wire [3:0]axi_smc_M00_AXI_WSTRB;
  wire axi_smc_M00_AXI_WVALID;
  wire [8:0]axi_smc_M01_AXI_ARADDR;
  wire axi_smc_M01_AXI_ARREADY;
  wire axi_smc_M01_AXI_ARVALID;
  wire [8:0]axi_smc_M01_AXI_AWADDR;
  wire axi_smc_M01_AXI_AWREADY;
  wire axi_smc_M01_AXI_AWVALID;
  wire axi_smc_M01_AXI_BREADY;
  wire [1:0]axi_smc_M01_AXI_BRESP;
  wire axi_smc_M01_AXI_BVALID;
  wire [31:0]axi_smc_M01_AXI_RDATA;
  wire axi_smc_M01_AXI_RREADY;
  wire [1:0]axi_smc_M01_AXI_RRESP;
  wire axi_smc_M01_AXI_RVALID;
  wire [31:0]axi_smc_M01_AXI_WDATA;
  wire axi_smc_M01_AXI_WREADY;
  wire [3:0]axi_smc_M01_AXI_WSTRB;
  wire axi_smc_M01_AXI_WVALID;
  wire [8:0]axi_smc_M02_AXI_ARADDR;
  wire axi_smc_M02_AXI_ARREADY;
  wire axi_smc_M02_AXI_ARVALID;
  wire [8:0]axi_smc_M02_AXI_AWADDR;
  wire axi_smc_M02_AXI_AWREADY;
  wire axi_smc_M02_AXI_AWVALID;
  wire axi_smc_M02_AXI_BREADY;
  wire [1:0]axi_smc_M02_AXI_BRESP;
  wire axi_smc_M02_AXI_BVALID;
  wire [31:0]axi_smc_M02_AXI_RDATA;
  wire axi_smc_M02_AXI_RREADY;
  wire [1:0]axi_smc_M02_AXI_RRESP;
  wire axi_smc_M02_AXI_RVALID;
  wire [31:0]axi_smc_M02_AXI_WDATA;
  wire axi_smc_M02_AXI_WREADY;
  wire [3:0]axi_smc_M02_AXI_WSTRB;
  wire axi_smc_M02_AXI_WVALID;
  wire i2c_aic_scl_i;
  wire i2c_aic_scl_o;
  wire i2c_aic_scl_t;
  wire i2c_aic_sda_i;
  wire i2c_aic_sda_o;
  wire i2c_aic_sda_t;
  wire [0:0]rst_ps8_0_96M_peripheral_aresetn;
  wire [39:0]zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_ARADDR;
  wire [1:0]zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_ARBURST;
  wire [3:0]zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_ARCACHE;
  wire [15:0]zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_ARID;
  wire [7:0]zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_ARLEN;
  wire zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_ARLOCK;
  wire [2:0]zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_ARPROT;
  wire [3:0]zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_ARQOS;
  wire zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_ARREADY;
  wire [2:0]zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_ARSIZE;
  wire [15:0]zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_ARUSER;
  wire zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_ARVALID;
  wire [39:0]zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_AWADDR;
  wire [1:0]zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_AWBURST;
  wire [3:0]zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_AWCACHE;
  wire [15:0]zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_AWID;
  wire [7:0]zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_AWLEN;
  wire zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_AWLOCK;
  wire [2:0]zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_AWPROT;
  wire [3:0]zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_AWQOS;
  wire zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_AWREADY;
  wire [2:0]zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_AWSIZE;
  wire [15:0]zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_AWUSER;
  wire zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_AWVALID;
  wire [15:0]zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_BID;
  wire zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_BREADY;
  wire [1:0]zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_BRESP;
  wire zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_BVALID;
  wire [31:0]zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_RDATA;
  wire [15:0]zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_RID;
  wire zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_RLAST;
  wire zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_RREADY;
  wire [1:0]zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_RRESP;
  wire zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_RVALID;
  wire [31:0]zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_WDATA;
  wire zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_WLAST;
  wire zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_WREADY;
  wire [3:0]zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_WSTRB;
  wire zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_WVALID;
  wire zynq_ultra_ps_e_0_pl_clk0;
  wire zynq_ultra_ps_e_0_pl_resetn0;

  audio_imp_FTOWPL audio
       (.AIC_lrclk_o(AIC_lrclk_o),
        .AIC_mclk_o(AIC_mclk_o),
        .AIC_nRST(AIC_nRST),
        .AIC_sclk_o(AIC_sclk_o),
        .AIC_sdata_i(AIC_sdata_i),
        .S_AXI2_araddr(axi_smc_M01_AXI_ARADDR),
        .S_AXI2_arready(axi_smc_M01_AXI_ARREADY),
        .S_AXI2_arvalid(axi_smc_M01_AXI_ARVALID),
        .S_AXI2_awaddr(axi_smc_M01_AXI_AWADDR),
        .S_AXI2_awready(axi_smc_M01_AXI_AWREADY),
        .S_AXI2_awvalid(axi_smc_M01_AXI_AWVALID),
        .S_AXI2_bready(axi_smc_M01_AXI_BREADY),
        .S_AXI2_bresp(axi_smc_M01_AXI_BRESP),
        .S_AXI2_bvalid(axi_smc_M01_AXI_BVALID),
        .S_AXI2_rdata(axi_smc_M01_AXI_RDATA),
        .S_AXI2_rready(axi_smc_M01_AXI_RREADY),
        .S_AXI2_rresp(axi_smc_M01_AXI_RRESP),
        .S_AXI2_rvalid(axi_smc_M01_AXI_RVALID),
        .S_AXI2_wdata(axi_smc_M01_AXI_WDATA),
        .S_AXI2_wready(axi_smc_M01_AXI_WREADY),
        .S_AXI2_wstrb(axi_smc_M01_AXI_WSTRB),
        .S_AXI2_wvalid(axi_smc_M01_AXI_WVALID),
        .S_AXI_araddr(axi_smc_M02_AXI_ARADDR),
        .S_AXI_arready(axi_smc_M02_AXI_ARREADY),
        .S_AXI_arvalid(axi_smc_M02_AXI_ARVALID),
        .S_AXI_awaddr(axi_smc_M02_AXI_AWADDR),
        .S_AXI_awready(axi_smc_M02_AXI_AWREADY),
        .S_AXI_awvalid(axi_smc_M02_AXI_AWVALID),
        .S_AXI_bready(axi_smc_M02_AXI_BREADY),
        .S_AXI_bresp(axi_smc_M02_AXI_BRESP),
        .S_AXI_bvalid(axi_smc_M02_AXI_BVALID),
        .S_AXI_rdata(axi_smc_M02_AXI_RDATA),
        .S_AXI_rready(axi_smc_M02_AXI_RREADY),
        .S_AXI_rresp(axi_smc_M02_AXI_RRESP),
        .S_AXI_rvalid(axi_smc_M02_AXI_RVALID),
        .S_AXI_wdata(axi_smc_M02_AXI_WDATA),
        .S_AXI_wready(axi_smc_M02_AXI_WREADY),
        .S_AXI_wstrb(axi_smc_M02_AXI_WSTRB),
        .S_AXI_wvalid(axi_smc_M02_AXI_WVALID),
        .i2c_aic_scl_i(i2c_aic_scl_i),
        .i2c_aic_scl_o(i2c_aic_scl_o),
        .i2c_aic_scl_t(i2c_aic_scl_t),
        .i2c_aic_sda_i(i2c_aic_sda_i),
        .i2c_aic_sda_o(i2c_aic_sda_o),
        .i2c_aic_sda_t(i2c_aic_sda_t),
        .i2s_sdata_o(AIC_sdata_o),
        .iic2intc_irpt(axi_iic_0_iic2intc_irpt),
        .m_axi_araddr(audio_m_axi_ARADDR),
        .m_axi_arburst(audio_m_axi_ARBURST),
        .m_axi_arcache(audio_m_axi_ARCACHE),
        .m_axi_arid(audio_m_axi_ARID),
        .m_axi_arlen(audio_m_axi_ARLEN),
        .m_axi_arlock(audio_m_axi_ARLOCK),
        .m_axi_arprot(audio_m_axi_ARPROT),
        .m_axi_arready(audio_m_axi_ARREADY),
        .m_axi_arsize(audio_m_axi_ARSIZE),
        .m_axi_arvalid(audio_m_axi_ARVALID),
        .m_axi_awaddr(audio_m_axi_AWADDR),
        .m_axi_awburst(audio_m_axi_AWBURST),
        .m_axi_awcache(audio_m_axi_AWCACHE),
        .m_axi_awid(audio_m_axi_AWID),
        .m_axi_awlen(audio_m_axi_AWLEN),
        .m_axi_awlock(audio_m_axi_AWLOCK),
        .m_axi_awprot(audio_m_axi_AWPROT),
        .m_axi_awready(audio_m_axi_AWREADY),
        .m_axi_awsize(audio_m_axi_AWSIZE),
        .m_axi_awvalid(audio_m_axi_AWVALID),
        .m_axi_bid(audio_m_axi_BID),
        .m_axi_bready(audio_m_axi_BREADY),
        .m_axi_bresp(audio_m_axi_BRESP),
        .m_axi_bvalid(audio_m_axi_BVALID),
        .m_axi_rdata(audio_m_axi_RDATA),
        .m_axi_rlast(audio_m_axi_RLAST),
        .m_axi_rready(audio_m_axi_RREADY),
        .m_axi_rresp(audio_m_axi_RRESP),
        .m_axi_rvalid(audio_m_axi_RVALID),
        .m_axi_wdata(audio_m_axi_WDATA),
        .m_axi_wlast(audio_m_axi_WLAST),
        .m_axi_wready(audio_m_axi_WREADY),
        .m_axi_wstrb(audio_m_axi_WSTRB),
        .m_axi_wvalid(audio_m_axi_WVALID),
        .resetn(zynq_ultra_ps_e_0_pl_resetn0),
        .s_axi1_araddr(axi_smc_M00_AXI_ARADDR),
        .s_axi1_arready(axi_smc_M00_AXI_ARREADY),
        .s_axi1_arvalid(axi_smc_M00_AXI_ARVALID),
        .s_axi1_awaddr(axi_smc_M00_AXI_AWADDR),
        .s_axi1_awready(axi_smc_M00_AXI_AWREADY),
        .s_axi1_awvalid(axi_smc_M00_AXI_AWVALID),
        .s_axi1_bready(axi_smc_M00_AXI_BREADY),
        .s_axi1_bresp(axi_smc_M00_AXI_BRESP),
        .s_axi1_bvalid(axi_smc_M00_AXI_BVALID),
        .s_axi1_rdata(axi_smc_M00_AXI_RDATA),
        .s_axi1_rready(axi_smc_M00_AXI_RREADY),
        .s_axi1_rresp(axi_smc_M00_AXI_RRESP),
        .s_axi1_rvalid(axi_smc_M00_AXI_RVALID),
        .s_axi1_wdata(axi_smc_M00_AXI_WDATA),
        .s_axi1_wready(axi_smc_M00_AXI_WREADY),
        .s_axi1_wstrb(axi_smc_M00_AXI_WSTRB),
        .s_axi1_wvalid(axi_smc_M00_AXI_WVALID),
        .s_axi_aclk(zynq_ultra_ps_e_0_pl_clk0),
        .s_axi_aresetn(rst_ps8_0_96M_peripheral_aresetn));
  hw_axi_smc_0 axi_smc
       (.M00_AXI_araddr(axi_smc_M00_AXI_ARADDR),
        .M00_AXI_arready(axi_smc_M00_AXI_ARREADY),
        .M00_AXI_arvalid(axi_smc_M00_AXI_ARVALID),
        .M00_AXI_awaddr(axi_smc_M00_AXI_AWADDR),
        .M00_AXI_awready(axi_smc_M00_AXI_AWREADY),
        .M00_AXI_awvalid(axi_smc_M00_AXI_AWVALID),
        .M00_AXI_bready(axi_smc_M00_AXI_BREADY),
        .M00_AXI_bresp(axi_smc_M00_AXI_BRESP),
        .M00_AXI_bvalid(axi_smc_M00_AXI_BVALID),
        .M00_AXI_rdata(axi_smc_M00_AXI_RDATA),
        .M00_AXI_rready(axi_smc_M00_AXI_RREADY),
        .M00_AXI_rresp(axi_smc_M00_AXI_RRESP),
        .M00_AXI_rvalid(axi_smc_M00_AXI_RVALID),
        .M00_AXI_wdata(axi_smc_M00_AXI_WDATA),
        .M00_AXI_wready(axi_smc_M00_AXI_WREADY),
        .M00_AXI_wstrb(axi_smc_M00_AXI_WSTRB),
        .M00_AXI_wvalid(axi_smc_M00_AXI_WVALID),
        .M01_AXI_araddr(axi_smc_M01_AXI_ARADDR),
        .M01_AXI_arready(axi_smc_M01_AXI_ARREADY),
        .M01_AXI_arvalid(axi_smc_M01_AXI_ARVALID),
        .M01_AXI_awaddr(axi_smc_M01_AXI_AWADDR),
        .M01_AXI_awready(axi_smc_M01_AXI_AWREADY),
        .M01_AXI_awvalid(axi_smc_M01_AXI_AWVALID),
        .M01_AXI_bready(axi_smc_M01_AXI_BREADY),
        .M01_AXI_bresp(axi_smc_M01_AXI_BRESP),
        .M01_AXI_bvalid(axi_smc_M01_AXI_BVALID),
        .M01_AXI_rdata(axi_smc_M01_AXI_RDATA),
        .M01_AXI_rready(axi_smc_M01_AXI_RREADY),
        .M01_AXI_rresp(axi_smc_M01_AXI_RRESP),
        .M01_AXI_rvalid(axi_smc_M01_AXI_RVALID),
        .M01_AXI_wdata(axi_smc_M01_AXI_WDATA),
        .M01_AXI_wready(axi_smc_M01_AXI_WREADY),
        .M01_AXI_wstrb(axi_smc_M01_AXI_WSTRB),
        .M01_AXI_wvalid(axi_smc_M01_AXI_WVALID),
        .M02_AXI_araddr(axi_smc_M02_AXI_ARADDR),
        .M02_AXI_arready(axi_smc_M02_AXI_ARREADY),
        .M02_AXI_arvalid(axi_smc_M02_AXI_ARVALID),
        .M02_AXI_awaddr(axi_smc_M02_AXI_AWADDR),
        .M02_AXI_awready(axi_smc_M02_AXI_AWREADY),
        .M02_AXI_awvalid(axi_smc_M02_AXI_AWVALID),
        .M02_AXI_bready(axi_smc_M02_AXI_BREADY),
        .M02_AXI_bresp(axi_smc_M02_AXI_BRESP),
        .M02_AXI_bvalid(axi_smc_M02_AXI_BVALID),
        .M02_AXI_rdata(axi_smc_M02_AXI_RDATA),
        .M02_AXI_rready(axi_smc_M02_AXI_RREADY),
        .M02_AXI_rresp(axi_smc_M02_AXI_RRESP),
        .M02_AXI_rvalid(axi_smc_M02_AXI_RVALID),
        .M02_AXI_wdata(axi_smc_M02_AXI_WDATA),
        .M02_AXI_wready(axi_smc_M02_AXI_WREADY),
        .M02_AXI_wstrb(axi_smc_M02_AXI_WSTRB),
        .M02_AXI_wvalid(axi_smc_M02_AXI_WVALID),
        .S00_AXI_araddr(zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_ARADDR),
        .S00_AXI_arburst(zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_ARBURST),
        .S00_AXI_arcache(zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_ARCACHE),
        .S00_AXI_arid(zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_ARID),
        .S00_AXI_arlen(zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_ARLEN),
        .S00_AXI_arlock(zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_ARLOCK),
        .S00_AXI_arprot(zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_ARPROT),
        .S00_AXI_arqos(zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_ARQOS),
        .S00_AXI_arready(zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_ARREADY),
        .S00_AXI_arsize(zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_ARSIZE),
        .S00_AXI_aruser(zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_ARUSER),
        .S00_AXI_arvalid(zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_ARVALID),
        .S00_AXI_awaddr(zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_AWADDR),
        .S00_AXI_awburst(zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_AWBURST),
        .S00_AXI_awcache(zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_AWCACHE),
        .S00_AXI_awid(zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_AWID),
        .S00_AXI_awlen(zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_AWLEN),
        .S00_AXI_awlock(zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_AWLOCK),
        .S00_AXI_awprot(zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_AWPROT),
        .S00_AXI_awqos(zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_AWQOS),
        .S00_AXI_awready(zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_AWREADY),
        .S00_AXI_awsize(zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_AWSIZE),
        .S00_AXI_awuser(zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_AWUSER),
        .S00_AXI_awvalid(zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_AWVALID),
        .S00_AXI_bid(zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_BID),
        .S00_AXI_bready(zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_BREADY),
        .S00_AXI_bresp(zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_BRESP),
        .S00_AXI_bvalid(zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_BVALID),
        .S00_AXI_rdata(zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_RDATA),
        .S00_AXI_rid(zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_RID),
        .S00_AXI_rlast(zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_RLAST),
        .S00_AXI_rready(zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_RREADY),
        .S00_AXI_rresp(zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_RRESP),
        .S00_AXI_rvalid(zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_RVALID),
        .S00_AXI_wdata(zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_WDATA),
        .S00_AXI_wlast(zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_WLAST),
        .S00_AXI_wready(zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_WREADY),
        .S00_AXI_wstrb(zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_WSTRB),
        .S00_AXI_wvalid(zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_WVALID),
        .aclk(zynq_ultra_ps_e_0_pl_clk0),
        .aresetn(rst_ps8_0_96M_peripheral_aresetn));
  hw_rst_ps8_0_96M_0 rst_ps8_0_96M
       (.aux_reset_in(1'b1),
        .dcm_locked(1'b1),
        .ext_reset_in(zynq_ultra_ps_e_0_pl_resetn0),
        .mb_debug_sys_rst(1'b0),
        .peripheral_aresetn(rst_ps8_0_96M_peripheral_aresetn),
        .slowest_sync_clk(zynq_ultra_ps_e_0_pl_clk0));
  hw_zynq_ultra_ps_e_0_0 zynq_ultra_ps_e_0
       (.maxigp2_araddr(zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_ARADDR),
        .maxigp2_arburst(zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_ARBURST),
        .maxigp2_arcache(zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_ARCACHE),
        .maxigp2_arid(zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_ARID),
        .maxigp2_arlen(zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_ARLEN),
        .maxigp2_arlock(zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_ARLOCK),
        .maxigp2_arprot(zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_ARPROT),
        .maxigp2_arqos(zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_ARQOS),
        .maxigp2_arready(zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_ARREADY),
        .maxigp2_arsize(zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_ARSIZE),
        .maxigp2_aruser(zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_ARUSER),
        .maxigp2_arvalid(zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_ARVALID),
        .maxigp2_awaddr(zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_AWADDR),
        .maxigp2_awburst(zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_AWBURST),
        .maxigp2_awcache(zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_AWCACHE),
        .maxigp2_awid(zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_AWID),
        .maxigp2_awlen(zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_AWLEN),
        .maxigp2_awlock(zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_AWLOCK),
        .maxigp2_awprot(zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_AWPROT),
        .maxigp2_awqos(zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_AWQOS),
        .maxigp2_awready(zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_AWREADY),
        .maxigp2_awsize(zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_AWSIZE),
        .maxigp2_awuser(zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_AWUSER),
        .maxigp2_awvalid(zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_AWVALID),
        .maxigp2_bid(zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_BID),
        .maxigp2_bready(zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_BREADY),
        .maxigp2_bresp(zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_BRESP),
        .maxigp2_bvalid(zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_BVALID),
        .maxigp2_rdata(zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_RDATA),
        .maxigp2_rid(zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_RID),
        .maxigp2_rlast(zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_RLAST),
        .maxigp2_rready(zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_RREADY),
        .maxigp2_rresp(zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_RRESP),
        .maxigp2_rvalid(zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_RVALID),
        .maxigp2_wdata(zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_WDATA),
        .maxigp2_wlast(zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_WLAST),
        .maxigp2_wready(zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_WREADY),
        .maxigp2_wstrb(zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_WSTRB),
        .maxigp2_wvalid(zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_WVALID),
        .maxihpm0_lpd_aclk(zynq_ultra_ps_e_0_pl_clk0),
        .pl_clk0(zynq_ultra_ps_e_0_pl_clk0),
        .pl_ps_irq0(axi_iic_0_iic2intc_irpt),
        .pl_resetn0(zynq_ultra_ps_e_0_pl_resetn0),
        .saxigp2_araddr({1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,audio_m_axi_ARADDR}),
        .saxigp2_arburst(audio_m_axi_ARBURST),
        .saxigp2_arcache(audio_m_axi_ARCACHE),
        .saxigp2_arid(audio_m_axi_ARID),
        .saxigp2_arlen(audio_m_axi_ARLEN),
        .saxigp2_arlock(audio_m_axi_ARLOCK),
        .saxigp2_arprot(audio_m_axi_ARPROT),
        .saxigp2_arqos({1'b0,1'b0,1'b0,1'b0}),
        .saxigp2_arready(audio_m_axi_ARREADY),
        .saxigp2_arsize(audio_m_axi_ARSIZE),
        .saxigp2_aruser(1'b0),
        .saxigp2_arvalid(audio_m_axi_ARVALID),
        .saxigp2_awaddr({1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,audio_m_axi_AWADDR}),
        .saxigp2_awburst(audio_m_axi_AWBURST),
        .saxigp2_awcache(audio_m_axi_AWCACHE),
        .saxigp2_awid(audio_m_axi_AWID),
        .saxigp2_awlen(audio_m_axi_AWLEN),
        .saxigp2_awlock(audio_m_axi_AWLOCK),
        .saxigp2_awprot(audio_m_axi_AWPROT),
        .saxigp2_awqos({1'b0,1'b0,1'b0,1'b0}),
        .saxigp2_awready(audio_m_axi_AWREADY),
        .saxigp2_awsize(audio_m_axi_AWSIZE),
        .saxigp2_awuser(1'b0),
        .saxigp2_awvalid(audio_m_axi_AWVALID),
        .saxigp2_bid(audio_m_axi_BID),
        .saxigp2_bready(audio_m_axi_BREADY),
        .saxigp2_bresp(audio_m_axi_BRESP),
        .saxigp2_bvalid(audio_m_axi_BVALID),
        .saxigp2_rdata(audio_m_axi_RDATA),
        .saxigp2_rlast(audio_m_axi_RLAST),
        .saxigp2_rready(audio_m_axi_RREADY),
        .saxigp2_rresp(audio_m_axi_RRESP),
        .saxigp2_rvalid(audio_m_axi_RVALID),
        .saxigp2_wdata(audio_m_axi_WDATA),
        .saxigp2_wlast(audio_m_axi_WLAST),
        .saxigp2_wready(audio_m_axi_WREADY),
        .saxigp2_wstrb(audio_m_axi_WSTRB),
        .saxigp2_wvalid(audio_m_axi_WVALID),
        .saxihp0_fpd_aclk(zynq_ultra_ps_e_0_pl_clk0));
endmodule
