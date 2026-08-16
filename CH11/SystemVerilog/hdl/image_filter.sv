// image_filter.sv
// ------------------------------------
// RGBA gray / Sobel / invert filter -- RTL equivalent of the Vitis HLS kernel
// ------------------------------------
// Author : Frank Bruno
//
// Same interfaces, same register map and bit-identical output to the HLS
// version in CH11/HLS, so it is a drop-in replacement in the block design and
// the same PYNQ notebook drives either one:
//
//   s_axi_control   AXI4-Lite, 6-bit address, 32-bit data
//   m_axi_gmem0     AXI4 read,  64-bit address, 32-bit data (one pixel/beat)
//   m_axi_gmem1     AXI4 write, 64-bit address, 32-bit data
//
// Dataflow, mirroring the three HLS stages:
//
//   gmem0 -> read master -> BT.601 luma -> FIFO -> core -> FIFO -> write master -> gmem1
//
// Pixels are packed RGBA with R in the low byte, which is what NumPy hands you
// for a uint8 (H,W,4) array on a little-endian machine.
`timescale 1ns/10ps
module image_filter
  #
  (
   parameter C_S_AXI_CONTROL_ADDR_WIDTH = 6,
   parameter C_S_AXI_CONTROL_DATA_WIDTH = 32,
   parameter C_M_AXI_GMEM_ADDR_WIDTH    = 64,
   parameter C_M_AXI_GMEM_DATA_WIDTH    = 32,
   parameter C_M_AXI_GMEM_ID_WIDTH      = 1,
   parameter MAX_WIDTH                  = 1920,
   parameter FIFO_DEPTH                 = 1024
   )
  (
   input wire                                  ap_clk,
   input wire                                  ap_rst_n,
   output wire                                 interrupt,

   // ---- AXI4-Lite control ----
   input wire [C_S_AXI_CONTROL_ADDR_WIDTH-1:0] s_axi_control_awaddr,
   input wire                                  s_axi_control_awvalid,
   output wire                                 s_axi_control_awready,
   input wire [C_S_AXI_CONTROL_DATA_WIDTH-1:0] s_axi_control_wdata,
   input wire [C_S_AXI_CONTROL_DATA_WIDTH/8-1:0] s_axi_control_wstrb,
   input wire                                  s_axi_control_wvalid,
   output wire                                 s_axi_control_wready,
   output wire [1:0]                           s_axi_control_bresp,
   output wire                                 s_axi_control_bvalid,
   input wire                                  s_axi_control_bready,
   input wire [C_S_AXI_CONTROL_ADDR_WIDTH-1:0] s_axi_control_araddr,
   input wire                                  s_axi_control_arvalid,
   output wire                                 s_axi_control_arready,
   output wire [C_S_AXI_CONTROL_DATA_WIDTH-1:0] s_axi_control_rdata,
   output wire [1:0]                           s_axi_control_rresp,
   output wire                                 s_axi_control_rvalid,
   input wire                                  s_axi_control_rready,

   // ---- AXI4 master, source ----
   output wire [C_M_AXI_GMEM_ID_WIDTH-1:0]     m_axi_gmem0_awid,
   output wire [C_M_AXI_GMEM_ADDR_WIDTH-1:0]   m_axi_gmem0_awaddr,
   output wire [7:0]                           m_axi_gmem0_awlen,
   output wire [2:0]                           m_axi_gmem0_awsize,
   output wire [1:0]                           m_axi_gmem0_awburst,
   output wire [1:0]                           m_axi_gmem0_awlock,
   output wire [3:0]                           m_axi_gmem0_awcache,
   output wire [2:0]                           m_axi_gmem0_awprot,
   output wire [3:0]                           m_axi_gmem0_awqos,
   output wire                                 m_axi_gmem0_awvalid,
   input wire                                  m_axi_gmem0_awready,
   output wire [C_M_AXI_GMEM_DATA_WIDTH-1:0]   m_axi_gmem0_wdata,
   output wire [C_M_AXI_GMEM_DATA_WIDTH/8-1:0] m_axi_gmem0_wstrb,
   output wire                                 m_axi_gmem0_wlast,
   output wire                                 m_axi_gmem0_wvalid,
   input wire                                  m_axi_gmem0_wready,
   input wire [C_M_AXI_GMEM_ID_WIDTH-1:0]      m_axi_gmem0_bid,
   input wire [1:0]                            m_axi_gmem0_bresp,
   input wire                                  m_axi_gmem0_bvalid,
   output wire                                 m_axi_gmem0_bready,
   output wire [C_M_AXI_GMEM_ID_WIDTH-1:0]     m_axi_gmem0_arid,
   output wire [C_M_AXI_GMEM_ADDR_WIDTH-1:0]   m_axi_gmem0_araddr,
   output wire [7:0]                           m_axi_gmem0_arlen,
   output wire [2:0]                           m_axi_gmem0_arsize,
   output wire [1:0]                           m_axi_gmem0_arburst,
   output wire [1:0]                           m_axi_gmem0_arlock,
   output wire [3:0]                           m_axi_gmem0_arcache,
   output wire [2:0]                           m_axi_gmem0_arprot,
   output wire [3:0]                           m_axi_gmem0_arqos,
   output wire                                 m_axi_gmem0_arvalid,
   input wire                                  m_axi_gmem0_arready,
   input wire [C_M_AXI_GMEM_ID_WIDTH-1:0]      m_axi_gmem0_rid,
   input wire [C_M_AXI_GMEM_DATA_WIDTH-1:0]    m_axi_gmem0_rdata,
   input wire [1:0]                            m_axi_gmem0_rresp,
   input wire                                  m_axi_gmem0_rlast,
   input wire                                  m_axi_gmem0_rvalid,
   output wire                                 m_axi_gmem0_rready,

   // ---- AXI4 master, destination ----
   output wire [C_M_AXI_GMEM_ID_WIDTH-1:0]     m_axi_gmem1_awid,
   output wire [C_M_AXI_GMEM_ADDR_WIDTH-1:0]   m_axi_gmem1_awaddr,
   output wire [7:0]                           m_axi_gmem1_awlen,
   output wire [2:0]                           m_axi_gmem1_awsize,
   output wire [1:0]                           m_axi_gmem1_awburst,
   output wire [1:0]                           m_axi_gmem1_awlock,
   output wire [3:0]                           m_axi_gmem1_awcache,
   output wire [2:0]                           m_axi_gmem1_awprot,
   output wire [3:0]                           m_axi_gmem1_awqos,
   output wire                                 m_axi_gmem1_awvalid,
   input wire                                  m_axi_gmem1_awready,
   output wire [C_M_AXI_GMEM_DATA_WIDTH-1:0]   m_axi_gmem1_wdata,
   output wire [C_M_AXI_GMEM_DATA_WIDTH/8-1:0] m_axi_gmem1_wstrb,
   output wire                                 m_axi_gmem1_wlast,
   output wire                                 m_axi_gmem1_wvalid,
   input wire                                  m_axi_gmem1_wready,
   input wire [C_M_AXI_GMEM_ID_WIDTH-1:0]      m_axi_gmem1_bid,
   input wire [1:0]                            m_axi_gmem1_bresp,
   input wire                                  m_axi_gmem1_bvalid,
   output wire                                 m_axi_gmem1_bready,
   output wire [C_M_AXI_GMEM_ID_WIDTH-1:0]     m_axi_gmem1_arid,
   output wire [C_M_AXI_GMEM_ADDR_WIDTH-1:0]   m_axi_gmem1_araddr,
   output wire [7:0]                           m_axi_gmem1_arlen,
   output wire [2:0]                           m_axi_gmem1_arsize,
   output wire [1:0]                           m_axi_gmem1_arburst,
   output wire [1:0]                           m_axi_gmem1_arlock,
   output wire [3:0]                           m_axi_gmem1_arcache,
   output wire [2:0]                           m_axi_gmem1_arprot,
   output wire [3:0]                           m_axi_gmem1_arqos,
   output wire                                 m_axi_gmem1_arvalid,
   input wire                                  m_axi_gmem1_arready,
   input wire [C_M_AXI_GMEM_ID_WIDTH-1:0]      m_axi_gmem1_rid,
   input wire [C_M_AXI_GMEM_DATA_WIDTH-1:0]    m_axi_gmem1_rdata,
   input wire [1:0]                            m_axi_gmem1_rresp,
   input wire                                  m_axi_gmem1_rlast,
   input wire                                  m_axi_gmem1_rvalid,
   output wire                                 m_axi_gmem1_rready
   );

  localparam CNT_W = $clog2(FIFO_DEPTH) + 1;

  wire        ap_start;
  wire        ap_done;
  wire [63:0] src_addr, dst_addr;
  wire [31:0] img_width, img_height, mode;

  // total pixels = words on both masters
  wire [31:0] total_words = img_width * img_height;

  // ------------------------------------------------------------------
  // Control
  // ------------------------------------------------------------------
  image_filter_ctrl
    #(.ADDR_WIDTH (C_S_AXI_CONTROL_ADDR_WIDTH),
      .DATA_WIDTH (C_S_AXI_CONTROL_DATA_WIDTH))
  u_ctrl
    (.clk        (ap_clk),
     .rst_n      (ap_rst_n),
     .awaddr     (s_axi_control_awaddr),
     .awvalid    (s_axi_control_awvalid),
     .awready    (s_axi_control_awready),
     .wdata      (s_axi_control_wdata),
     .wstrb      (s_axi_control_wstrb),
     .wvalid     (s_axi_control_wvalid),
     .wready     (s_axi_control_wready),
     .bresp      (s_axi_control_bresp),
     .bvalid     (s_axi_control_bvalid),
     .bready     (s_axi_control_bready),
     .araddr     (s_axi_control_araddr),
     .arvalid    (s_axi_control_arvalid),
     .arready    (s_axi_control_arready),
     .rdata      (s_axi_control_rdata),
     .rresp      (s_axi_control_rresp),
     .rvalid     (s_axi_control_rvalid),
     .rready     (s_axi_control_rready),
     .interrupt  (interrupt),
     .ap_start   (ap_start),
     .ap_done    (ap_done),
     .src_addr   (src_addr),
     .dst_addr   (dst_addr),
     .img_width  (img_width),
     .img_height (img_height),
     .mode       (mode));

  // ap_start is a level; the engines want a single-cycle launch pulse.
  reg  ap_start_d;
  wire launch;
  always @(posedge ap_clk) begin
    if (!ap_rst_n) ap_start_d <= 1'b0;
    else           ap_start_d <= ap_start;
  end
  assign launch = ap_start & ~ap_start_d;

  // ------------------------------------------------------------------
  // Read path: gmem0 -> luma -> input FIFO
  // ------------------------------------------------------------------
  wire        rd_valid, rd_ready;
  wire [31:0] rd_data;
  wire [CNT_W-1:0] in_count;
  wire        in_full, in_empty;
  wire [7:0]  in_dout;
  wire        core_s_ready;

  wire [CNT_W-1:0] in_free = FIFO_DEPTH[CNT_W-1:0] - in_count;

  image_filter_rd
    #(.ADDR_WIDTH (C_M_AXI_GMEM_ADDR_WIDTH),
      .DATA_WIDTH (C_M_AXI_GMEM_DATA_WIDTH),
      .ID_WIDTH   (C_M_AXI_GMEM_ID_WIDTH),
      .CNT_WIDTH  (CNT_W))
  u_rd
    (.clk         (ap_clk),
     .rst_n       (ap_rst_n),
     .start       (launch),
     .base_addr   (src_addr),
     .total_words (total_words),
     .busy        (),
     .arid        (m_axi_gmem0_arid),
     .araddr      (m_axi_gmem0_araddr),
     .arlen       (m_axi_gmem0_arlen),
     .arsize      (m_axi_gmem0_arsize),
     .arburst     (m_axi_gmem0_arburst),
     .arvalid     (m_axi_gmem0_arvalid),
     .arready     (m_axi_gmem0_arready),
     .rdata       (m_axi_gmem0_rdata),
     .rresp       (m_axi_gmem0_rresp),
     .rlast       (m_axi_gmem0_rlast),
     .rvalid      (m_axi_gmem0_rvalid),
     .rready      (m_axi_gmem0_rready),
     .m_valid     (rd_valid),
     .m_data      (rd_data),
     .m_ready     (rd_ready),
     .m_free      (in_free));

  assign rd_ready = !in_full;

  // ITU-R BT.601 luma in Q8: 0.299/0.587/0.114 -> 77/150/29
  wire [7:0] px_r = rd_data[7:0];
  wire [7:0] px_g = rd_data[15:8];
  wire [7:0] px_b = rd_data[23:16];
  wire [17:0] luma_sum = (18'd77 * px_r) + (18'd150 * px_g) + (18'd29 * px_b);
  wire [7:0]  luma = luma_sum[15:8];

  sync_fifo #(.WIDTH (8), .DEPTH (FIFO_DEPTH))
  u_fifo_in
    (.clk    (ap_clk),
     .rst_n  (ap_rst_n),
     .wr_en  (rd_valid && rd_ready),
     .din    (luma),
     .rd_en  (core_s_ready),
     .dout   (in_dout),
     .empty  (in_empty),
     .full   (in_full),
     .count  (in_count));

  // ------------------------------------------------------------------
  // Core
  // ------------------------------------------------------------------
  wire       core_m_valid, core_m_ready;
  wire [7:0] core_m_data;
  wire       core_done;

  image_filter_core #(.MAX_WIDTH (MAX_WIDTH))
  u_core
    (.clk        (ap_clk),
     .rst_n      (ap_rst_n),
     .start      (launch),
     .img_width  (img_width[15:0]),
     .img_height (img_height[15:0]),
     .mode       (mode),
     .done       (core_done),
     .s_valid    (!in_empty),
     .s_data     (in_dout),
     .s_ready    (core_s_ready),
     .m_valid    (core_m_valid),
     .m_data     (core_m_data),
     .m_ready    (core_m_ready));

  // ------------------------------------------------------------------
  // Write path: output FIFO -> RGBA expand -> gmem1
  // ------------------------------------------------------------------
  wire        out_full, out_empty;
  wire [7:0]  out_dout;
  wire [CNT_W-1:0] out_count;
  wire        wr_s_ready;

  assign core_m_ready = !out_full;

  sync_fifo #(.WIDTH (8), .DEPTH (FIFO_DEPTH))
  u_fifo_out
    (.clk    (ap_clk),
     .rst_n  (ap_rst_n),
     .wr_en  (core_m_valid && core_m_ready),
     .din    (core_m_data),
     .rd_en  (wr_s_ready),
     .dout   (out_dout),
     .empty  (out_empty),
     .full   (out_full),
     .count  (out_count));

  // luma replicated across R/G/B, alpha forced opaque
  wire [31:0] out_pixel = {8'hFF, out_dout, out_dout, out_dout};

  wire wr_done;

  image_filter_wr
    #(.ADDR_WIDTH (C_M_AXI_GMEM_ADDR_WIDTH),
      .DATA_WIDTH (C_M_AXI_GMEM_DATA_WIDTH),
      .ID_WIDTH   (C_M_AXI_GMEM_ID_WIDTH),
      .CNT_WIDTH  (CNT_W))
  u_wr
    (.clk         (ap_clk),
     .rst_n       (ap_rst_n),
     .start       (launch),
     .base_addr   (dst_addr),
     .total_words (total_words),
     .busy        (),
     .done        (wr_done),
     .awid        (m_axi_gmem1_awid),
     .awaddr      (m_axi_gmem1_awaddr),
     .awlen       (m_axi_gmem1_awlen),
     .awsize      (m_axi_gmem1_awsize),
     .awburst     (m_axi_gmem1_awburst),
     .awvalid     (m_axi_gmem1_awvalid),
     .awready     (m_axi_gmem1_awready),
     .wdata       (m_axi_gmem1_wdata),
     .wstrb       (m_axi_gmem1_wstrb),
     .wlast       (m_axi_gmem1_wlast),
     .wvalid      (m_axi_gmem1_wvalid),
     .wready      (m_axi_gmem1_wready),
     .bresp       (m_axi_gmem1_bresp),
     .bvalid      (m_axi_gmem1_bvalid),
     .bready      (m_axi_gmem1_bready),
     .s_valid     (!out_empty),
     .s_data      (out_pixel),
     .s_ready     (wr_s_ready),
     .s_count     (out_count));

  // The kernel is finished when the last write response has come back. A
  // zero-sized image never starts an engine, so complete it off the core.
  wire zero_sized = (total_words == 32'd0);
  assign ap_done = wr_done | (zero_sized & core_done);

  // ------------------------------------------------------------------
  // Unused master signals -- gmem0 never writes, gmem1 never reads
  // ------------------------------------------------------------------
  assign m_axi_gmem0_awid    = '0;
  assign m_axi_gmem0_awaddr  = '0;
  assign m_axi_gmem0_awlen   = '0;
  assign m_axi_gmem0_awsize  = 3'b010;
  assign m_axi_gmem0_awburst = 2'b01;
  assign m_axi_gmem0_awvalid = 1'b0;
  assign m_axi_gmem0_wdata   = '0;
  assign m_axi_gmem0_wstrb   = '0;
  assign m_axi_gmem0_wlast   = 1'b0;
  assign m_axi_gmem0_wvalid  = 1'b0;
  assign m_axi_gmem0_bready  = 1'b1;
  assign m_axi_gmem0_awlock  = 2'b00;
  assign m_axi_gmem0_awcache = 4'b0011;
  assign m_axi_gmem0_awprot  = 3'b000;
  assign m_axi_gmem0_awqos   = 4'b0000;
  assign m_axi_gmem0_arlock  = 2'b00;
  assign m_axi_gmem0_arcache = 4'b0011;
  assign m_axi_gmem0_arprot  = 3'b000;
  assign m_axi_gmem0_arqos   = 4'b0000;

  assign m_axi_gmem1_arid    = '0;
  assign m_axi_gmem1_araddr  = '0;
  assign m_axi_gmem1_arlen   = '0;
  assign m_axi_gmem1_arsize  = 3'b010;
  assign m_axi_gmem1_arburst = 2'b01;
  assign m_axi_gmem1_arvalid = 1'b0;
  assign m_axi_gmem1_rready  = 1'b1;
  assign m_axi_gmem1_awlock  = 2'b00;
  assign m_axi_gmem1_awcache = 4'b0011;
  assign m_axi_gmem1_awprot  = 3'b000;
  assign m_axi_gmem1_awqos   = 4'b0000;
  assign m_axi_gmem1_arlock  = 2'b00;
  assign m_axi_gmem1_arcache = 4'b0011;
  assign m_axi_gmem1_arprot  = 3'b000;
  assign m_axi_gmem1_arqos   = 4'b0000;

endmodule
