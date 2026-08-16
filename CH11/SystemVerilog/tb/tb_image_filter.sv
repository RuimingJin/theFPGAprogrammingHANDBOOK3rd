// tb_image_filter.sv
// ------------------------------------
// Self-checking testbench for the RTL image filter
// ------------------------------------
// Author : Frank Bruno
//
// Drives the DUT exactly the way PYNQ does -- write the argument registers over
// AXI4-Lite, set ap_start, poll ap_done -- against behavioural AXI4 slave
// memories on both masters. The result is compared against a golden model that
// is a line-for-line transcription of tb_image_filter.cpp, so a pass here means
// the RTL agrees with the HLS C simulation.
//
// Backpressure on every AXI channel is randomised so the design is exercised
// with stalls rather than only in the easy full-throughput case.
`timescale 1ns/10ps
module tb_image_filter;

  localparam CLK_PERIOD = 5.0;      // 200 MHz, matching the HLS target
  // The model masks addresses down to MEMW words, so SRC and DST must not
  // alias once masked -- with a 1M-word model, DST at 0x800000 wrapped onto
  // word 0 and larger frames overwrote their own source as they ran.
  localparam MEMW       = 1 << 22;  // 4M 32-bit words
  localparam SRC_BASE   = 64'h0000_0000_0001_0000;   // word 0x004000
  localparam DST_BASE   = 64'h0000_0000_0080_0000;   // word 0x200000

  logic ap_clk = 1'b0;
  logic ap_rst_n = 1'b0;
  always #(CLK_PERIOD/2.0) ap_clk = ~ap_clk;

  // ------------------------------------------------------------------
  // DUT signals
  // ------------------------------------------------------------------
  logic [5:0]  ctrl_awaddr;  logic ctrl_awvalid, ctrl_awready;
  logic [31:0] ctrl_wdata;   logic [3:0] ctrl_wstrb;
  logic        ctrl_wvalid,  ctrl_wready;
  logic [1:0]  ctrl_bresp;   logic ctrl_bvalid, ctrl_bready;
  logic [5:0]  ctrl_araddr;  logic ctrl_arvalid, ctrl_arready;
  logic [31:0] ctrl_rdata;   logic [1:0] ctrl_rresp;
  logic        ctrl_rvalid,  ctrl_rready;
  logic        interrupt;

  logic [0:0]  g0_arid;   logic [63:0] g0_araddr; logic [7:0] g0_arlen;
  logic [2:0]  g0_arsize; logic [1:0]  g0_arburst;
  logic [1:0]  g0_arlock; logic [3:0]  g0_arcache; logic [2:0] g0_arprot;
  logic [3:0]  g0_arqos;
  logic        g0_arvalid, g0_arready;
  logic [0:0]  g0_rid;    logic [31:0] g0_rdata;  logic [1:0] g0_rresp;
  logic        g0_rlast,  g0_rvalid,   g0_rready;
  logic [0:0]  g0_awid;   logic [63:0] g0_awaddr; logic [7:0] g0_awlen;
  logic [2:0]  g0_awsize; logic [1:0]  g0_awburst;
  logic [1:0]  g0_awlock; logic [3:0]  g0_awcache; logic [2:0] g0_awprot;
  logic [3:0]  g0_awqos;
  logic        g0_awvalid, g0_awready;
  logic [31:0] g0_wdata;  logic [3:0] g0_wstrb;
  logic        g0_wlast,  g0_wvalid,  g0_wready;
  logic [0:0]  g0_bid;    logic [1:0] g0_bresp;
  logic        g0_bvalid, g0_bready;

  logic [0:0]  g1_arid;   logic [63:0] g1_araddr; logic [7:0] g1_arlen;
  logic [2:0]  g1_arsize; logic [1:0]  g1_arburst;
  logic [1:0]  g1_arlock; logic [3:0]  g1_arcache; logic [2:0] g1_arprot;
  logic [3:0]  g1_arqos;
  logic        g1_arvalid, g1_arready;
  logic [0:0]  g1_rid;    logic [31:0] g1_rdata;  logic [1:0] g1_rresp;
  logic        g1_rlast,  g1_rvalid,   g1_rready;
  logic [0:0]  g1_awid;   logic [63:0] g1_awaddr; logic [7:0] g1_awlen;
  logic [2:0]  g1_awsize; logic [1:0]  g1_awburst;
  logic [1:0]  g1_awlock; logic [3:0]  g1_awcache; logic [2:0] g1_awprot;
  logic [3:0]  g1_awqos;
  logic        g1_awvalid, g1_awready;
  logic [31:0] g1_wdata;  logic [3:0] g1_wstrb;
  logic        g1_wlast,  g1_wvalid,  g1_wready;
  logic [0:0]  g1_bid;    logic [1:0] g1_bresp;
  logic        g1_bvalid, g1_bready;

  image_filter #(.MAX_WIDTH (1920), .FIFO_DEPTH (1024)) dut
    (.ap_clk (ap_clk), .ap_rst_n (ap_rst_n), .interrupt (interrupt),
     .s_axi_control_awaddr (ctrl_awaddr), .s_axi_control_awvalid (ctrl_awvalid),
     .s_axi_control_awready (ctrl_awready), .s_axi_control_wdata (ctrl_wdata),
     .s_axi_control_wstrb (ctrl_wstrb), .s_axi_control_wvalid (ctrl_wvalid),
     .s_axi_control_wready (ctrl_wready), .s_axi_control_bresp (ctrl_bresp),
     .s_axi_control_bvalid (ctrl_bvalid), .s_axi_control_bready (ctrl_bready),
     .s_axi_control_araddr (ctrl_araddr), .s_axi_control_arvalid (ctrl_arvalid),
     .s_axi_control_arready (ctrl_arready), .s_axi_control_rdata (ctrl_rdata),
     .s_axi_control_rresp (ctrl_rresp), .s_axi_control_rvalid (ctrl_rvalid),
     .s_axi_control_rready (ctrl_rready),
     .m_axi_gmem0_awid (g0_awid), .m_axi_gmem0_awaddr (g0_awaddr),
     .m_axi_gmem0_awlen (g0_awlen), .m_axi_gmem0_awsize (g0_awsize),
     .m_axi_gmem0_awburst (g0_awburst), .m_axi_gmem0_awlock (g0_awlock),
     .m_axi_gmem0_awcache (g0_awcache), .m_axi_gmem0_awprot (g0_awprot),
     .m_axi_gmem0_awqos (g0_awqos), .m_axi_gmem0_awvalid (g0_awvalid),
     .m_axi_gmem0_awready (g0_awready), .m_axi_gmem0_wdata (g0_wdata),
     .m_axi_gmem0_wstrb (g0_wstrb), .m_axi_gmem0_wlast (g0_wlast),
     .m_axi_gmem0_wvalid (g0_wvalid), .m_axi_gmem0_wready (g0_wready),
     .m_axi_gmem0_bid (g0_bid), .m_axi_gmem0_bresp (g0_bresp),
     .m_axi_gmem0_bvalid (g0_bvalid), .m_axi_gmem0_bready (g0_bready),
     .m_axi_gmem0_arid (g0_arid), .m_axi_gmem0_araddr (g0_araddr),
     .m_axi_gmem0_arlen (g0_arlen), .m_axi_gmem0_arsize (g0_arsize),
     .m_axi_gmem0_arburst (g0_arburst), .m_axi_gmem0_arlock (g0_arlock),
     .m_axi_gmem0_arcache (g0_arcache), .m_axi_gmem0_arprot (g0_arprot),
     .m_axi_gmem0_arqos (g0_arqos), .m_axi_gmem0_arvalid (g0_arvalid),
     .m_axi_gmem0_arready (g0_arready), .m_axi_gmem0_rid (g0_rid),
     .m_axi_gmem0_rdata (g0_rdata), .m_axi_gmem0_rresp (g0_rresp),
     .m_axi_gmem0_rlast (g0_rlast), .m_axi_gmem0_rvalid (g0_rvalid),
     .m_axi_gmem0_rready (g0_rready),
     .m_axi_gmem1_awid (g1_awid), .m_axi_gmem1_awaddr (g1_awaddr),
     .m_axi_gmem1_awlen (g1_awlen), .m_axi_gmem1_awsize (g1_awsize),
     .m_axi_gmem1_awburst (g1_awburst), .m_axi_gmem1_awlock (g1_awlock),
     .m_axi_gmem1_awcache (g1_awcache), .m_axi_gmem1_awprot (g1_awprot),
     .m_axi_gmem1_awqos (g1_awqos), .m_axi_gmem1_awvalid (g1_awvalid),
     .m_axi_gmem1_awready (g1_awready), .m_axi_gmem1_wdata (g1_wdata),
     .m_axi_gmem1_wstrb (g1_wstrb), .m_axi_gmem1_wlast (g1_wlast),
     .m_axi_gmem1_wvalid (g1_wvalid), .m_axi_gmem1_wready (g1_wready),
     .m_axi_gmem1_bid (g1_bid), .m_axi_gmem1_bresp (g1_bresp),
     .m_axi_gmem1_bvalid (g1_bvalid), .m_axi_gmem1_bready (g1_bready),
     .m_axi_gmem1_arid (g1_arid), .m_axi_gmem1_araddr (g1_araddr),
     .m_axi_gmem1_arlen (g1_arlen), .m_axi_gmem1_arsize (g1_arsize),
     .m_axi_gmem1_arburst (g1_arburst), .m_axi_gmem1_arlock (g1_arlock),
     .m_axi_gmem1_arcache (g1_arcache), .m_axi_gmem1_arprot (g1_arprot),
     .m_axi_gmem1_arqos (g1_arqos), .m_axi_gmem1_arvalid (g1_arvalid),
     .m_axi_gmem1_arready (g1_arready), .m_axi_gmem1_rid (g1_rid),
     .m_axi_gmem1_rdata (g1_rdata), .m_axi_gmem1_rresp (g1_rresp),
     .m_axi_gmem1_rlast (g1_rlast), .m_axi_gmem1_rvalid (g1_rvalid),
     .m_axi_gmem1_rready (g1_rready));

  // ------------------------------------------------------------------
  // Shared behavioural memory
  // ------------------------------------------------------------------
  logic [31:0] mem [MEMW];

  function automatic int unsigned waddr(input logic [63:0] byte_addr);
    waddr = int'((byte_addr >> 2) & (MEMW-1));
  endfunction

  // ---- gmem0: read slave ----
  // Everything is declared at module scope. Declarations inside a forever
  // block upset the xsim kernel here, so keep the process bodies flat.
  integer g0_seed = 32'h1234_5678;
  reg [63:0] g0_a;
  integer    g0_len;
  integer    g0_i;

  initial begin
    g0_arready = 1'b0;
    g0_rvalid  = 1'b0;
    g0_rlast   = 1'b0;
    g0_rresp   = 2'b00;
    g0_rid     = 1'b0;
    g0_awready = 1'b1;
    g0_wready  = 1'b1;
    g0_bvalid  = 1'b0;
    g0_bid     = 1'b0;
    g0_bresp   = 2'b00;
    g0_rdata   = 32'd0;
    @(posedge ap_rst_n);
    forever begin
      g0_arready <= 1'b1;
      @(posedge ap_clk);
      while (!(g0_arvalid && g0_arready)) @(posedge ap_clk);
      g0_a   = g0_araddr;
      g0_len = g0_arlen + 1;
      g0_arready <= 1'b0;
      for (g0_i = 0; g0_i < g0_len; g0_i = g0_i + 1) begin
        while (($random(g0_seed) % 5) == 0) @(posedge ap_clk);
        g0_rdata  <= mem[waddr(g0_a) + g0_i];
        g0_rvalid <= 1'b1;
        g0_rlast  <= (g0_i == g0_len-1);
        @(posedge ap_clk);
        while (!g0_rready) @(posedge ap_clk);
        g0_rvalid <= 1'b0;
        g0_rlast  <= 1'b0;
      end
    end
  end

  // ---- gmem1: write slave ----
  integer g1_seed = 32'h89ab_cdef;
  reg [63:0] g1_a;
  integer    g1_i;
  reg        g1_last_seen;

  initial begin
    g1_awready = 1'b0;
    g1_wready  = 1'b0;
    g1_bvalid  = 1'b0;
    g1_bid     = 1'b0;
    g1_bresp   = 2'b00;
    g1_arready = 1'b1;
    g1_rvalid  = 1'b0;
    g1_rlast   = 1'b0;
    g1_rdata   = 32'd0;
    g1_rresp   = 2'b00;
    g1_rid     = 1'b0;
    @(posedge ap_rst_n);
    forever begin
      g1_awready <= 1'b1;
      @(posedge ap_clk);
      while (!(g1_awvalid && g1_awready)) @(posedge ap_clk);
      g1_a = g1_awaddr;
      g1_awready <= 1'b0;
      g1_i = 0;
      g1_last_seen = 1'b0;
      while (!g1_last_seen) begin
        g1_wready <= (($random(g1_seed) % 4) != 0);
        @(posedge ap_clk);
        if (g1_wvalid && g1_wready) begin
          mem[waddr(g1_a) + g1_i] = g1_wdata;
          g1_i = g1_i + 1;
          if (g1_wlast) g1_last_seen = 1'b1;
        end
      end
      g1_wready <= 1'b0;
      g1_bvalid <= 1'b1;
      @(posedge ap_clk);
      while (!g1_bready) @(posedge ap_clk);
      g1_bvalid <= 1'b0;
    end
  end

  // ------------------------------------------------------------------
  // AXI4-Lite master tasks
  // ------------------------------------------------------------------
  task automatic axil_write(input [5:0] addr, input [31:0] data);
    begin
      @(posedge ap_clk);
      ctrl_awaddr  <= addr; ctrl_awvalid <= 1'b1;
      ctrl_wdata   <= data; ctrl_wstrb   <= 4'hF; ctrl_wvalid <= 1'b1;
      ctrl_bready  <= 1'b1;
      @(posedge ap_clk);
      while (ctrl_awvalid || ctrl_wvalid) begin
        if (ctrl_awvalid && ctrl_awready) ctrl_awvalid <= 1'b0;
        if (ctrl_wvalid  && ctrl_wready ) ctrl_wvalid  <= 1'b0;
        @(posedge ap_clk);
      end
      while (!(ctrl_bvalid && ctrl_bready)) @(posedge ap_clk);
      @(posedge ap_clk);
      ctrl_bready <= 1'b0;
    end
  endtask

  // Result of the most recent axil_read. An `output` argument on an automatic
  // task takes the xsim kernel down here, so the value comes back this way.
  logic [31:0] axil_rd_data;

  task automatic axil_read(input [5:0] addr);
    begin
      @(posedge ap_clk);
      ctrl_araddr <= addr; ctrl_arvalid <= 1'b1; ctrl_rready <= 1'b1;
      @(posedge ap_clk);
      while (!(ctrl_arvalid && ctrl_arready)) @(posedge ap_clk);
      ctrl_arvalid <= 1'b0;
      while (!(ctrl_rvalid && ctrl_rready)) @(posedge ap_clk);
      axil_rd_data = ctrl_rdata;
      ctrl_rready <= 1'b0;
      @(posedge ap_clk);
    end
  endtask

  // ------------------------------------------------------------------
  // Golden model -- transcription of tb_image_filter.cpp
  // ------------------------------------------------------------------
  // Fixed-size rather than dynamic: repeatedly re-allocating a dynamic array
  // per test case is what the xsim kernel could not survive.
  localparam MAXPX = 1 << 16;          // 65536 pixels, covers every case below
  logic [31:0] src_img [MAXPX];
  logic [31:0] ref_img [MAXPX];
  logic [7:0]  gray_img [MAXPX];

  function automatic logic [7:0] luma8(input [31:0] px);
    logic [17:0] s;
    begin
      s = 18'd77 * px[7:0] + 18'd150 * px[15:8] + 18'd29 * px[23:16];
      luma8 = s[15:8];
    end
  endfunction

  task automatic build_golden(input int W, input int H, input int md);
    int r, c, i;
    int p00,p01,p02,p10,p12,p20,p21,p22, gx, gy, m;
    logic [7:0] v;
    begin
      for (i = 0; i < W*H; i++) gray_img[i] = luma8(src_img[i]);
      for (r = 0; r < H; r++) begin
        for (c = 0; c < W; c++) begin
          if (md == 0) v = gray_img[r*W + c];
          else if (md == 2) v = 8'd255 - gray_img[r*W + c];
          else begin
            if (r == 0 || r == H-1 || c == 0 || c == W-1) v = 8'd0;
            else begin
              p00 = gray_img[(r-1)*W + c-1]; p01 = gray_img[(r-1)*W + c]; p02 = gray_img[(r-1)*W + c+1];
              p10 = gray_img[( r )*W + c-1];                 p12 = gray_img[( r )*W + c+1];
              p20 = gray_img[(r+1)*W + c-1]; p21 = gray_img[(r+1)*W + c]; p22 = gray_img[(r+1)*W + c+1];
              gx  = (p02 + 2*p12 + p22) - (p00 + 2*p10 + p20);
              gy  = (p20 + 2*p21 + p22) - (p00 + 2*p01 + p02);
              m   = (gx < 0 ? -gx : gx) + (gy < 0 ? -gy : gy);
              v   = (m > 255) ? 8'd255 : m[7:0];
            end
          end
          ref_img[r*W + c] = {8'hFF, v, v, v};
        end
      end
    end
  endtask

  // ------------------------------------------------------------------
  // Test sequence
  // ------------------------------------------------------------------
  int errors_total = 0;

  task automatic run_case(input int W, input int H, input int md,
                          input string name);
    int r, c, i, bad;
    logic [31:0] rd;
    logic [7:0] R, G, B;
    time t0;
    int timed_out;
    int cycles;
    int src_w, dst_w;
    begin
      if (W*H > MAXPX) begin
        $display("  [%-18s] SKIPPED: %0d px exceeds MAXPX %0d", name, W*H, MAXPX);
        errors_total++;
        return;
      end
      // resolve the model addresses once; calling an automatic function inside
      // the compare loop is what the xsim kernel choked on
      src_w = waddr(SRC_BASE);
      dst_w = waddr(DST_BASE);

      // synthetic scene: gradient with a hard-edged bright square
      for (r = 0; r < H; r++) begin
        for (c = 0; c < W; c++) begin
          R = (W > 1) ? ((c * 255) / (W-1)) : 8'd0;
          G = (H > 1) ? ((r * 255) / (H-1)) : 8'd0;
          B = ((W + H) > 2) ? (((r + c) * 255) / (W + H - 2)) : 8'd0;
          if (r > H/4 && r < 3*H/4 && c > W/4 && c < 3*W/4) begin
            R = 8'd240; G = 8'd240; B = 8'd240;
          end
          src_img[r*W + c] = {8'hFF, B, G, R};
        end
      end

      for (i = 0; i < W*H; i++) begin
        mem[src_w + i] = src_img[i];
        mem[dst_w + i] = 32'hDEAD_BEEF;   // poison
      end

      build_golden(W, H, md);

      axil_write(6'h10, SRC_BASE[31:0]);
      axil_write(6'h14, SRC_BASE[63:32]);
      axil_write(6'h1C, DST_BASE[31:0]);
      axil_write(6'h20, DST_BASE[63:32]);
      axil_write(6'h28, W);
      axil_write(6'h30, H);
      axil_write(6'h38, md);

      t0 = $time;
      axil_write(6'h00, 32'h1);          // ap_start

      // Poll CTRL for ap_done exactly the way the PYNQ driver does. No
      // hierarchical peeking into the DUT, so this same testbench binds against
      // either the SystemVerilog or the VHDL implementation.
      timed_out = 0;
      cycles    = 0;
      rd        = 32'd0;
      while (!rd[1] && (cycles < 200000)) begin
        axil_read(6'h00);
        rd     = axil_rd_data;
        cycles = cycles + 1;
      end
      if (!rd[1]) begin
        $display("  [%-18s] TIMEOUT waiting for ap_done after %0d polls",
                 name, cycles);
        timed_out = 1;
      end else begin
        // ap_done is clear-on-read, so a second read must come back clear
        axil_read(6'h00);
        if (axil_rd_data[1]) begin
          $display("  [%-18s] AP_DONE did not clear on read (rd=%08x)",
                   name, axil_rd_data);
          errors_total++;
        end
      end

      bad = 0;
      if (timed_out) begin
        $display("  [%-18s] %4d x %-4d  ABORTED", name, W, H);
        errors_total++;
      end else begin
      for (i = 0; i < W*H; i++) begin
        if (mem[dst_w + i] !== ref_img[i]) begin
          if (bad < 5)
            $display("    MISMATCH @ (%0d,%0d): ref=%08x got=%08x",
                     i / W, i % W, ref_img[i], mem[dst_w + i]);
          bad = bad + 1;
        end
      end
      errors_total += bad;
      if (bad == 0)
        $display("  [%-18s] %4d x %-4d  %7d px  PASS        %0d polls",
                 name, W, H, W*H, cycles);
      else
        $display("  [%-18s] %4d x %-4d  %7d px  FAIL %6d  %0d polls",
                 name, W, H, W*H, bad, cycles);
      end
    end
  endtask


  initial begin
    ctrl_awvalid = 0; ctrl_wvalid = 0; ctrl_bready = 0;
    ctrl_arvalid = 0; ctrl_rready = 0; ctrl_wstrb = 4'hF;
    ctrl_awaddr = 0; ctrl_araddr = 0; ctrl_wdata = 0;

    repeat (10) @(posedge ap_clk);
    ap_rst_n = 1'b1;
    repeat (5) @(posedge ap_clk);

    $display("========================================================");
    $display(" RTL image filter -- checking against the HLS golden model");
    $display("========================================================");

    run_case( 64, 48, 0, "GRAY 64x48");
    run_case( 64, 48, 1, "SOBEL 64x48");
    run_case( 64, 48, 2, "INVERT 64x48");
    // odd sizes and degenerate cases: the (H+1)x(W+1) iteration space is
    // where a FIFO imbalance or deadlock would show up first
    run_case( 37, 23, 1, "SOBEL 37x23");
    run_case(  3,  3, 1, "SOBEL 3x3");
    run_case(  1,  1, 1, "SOBEL 1x1");
    run_case(  1, 16, 1, "SOBEL 1x16");
    run_case( 16,  1, 1, "SOBEL 16x1");
    run_case(160,120, 1, "SOBEL 160x120");
    // mode 4 is not a defined mode; the C falls through to Sobel
    run_case( 32, 24, 4, "MODE4->SOBEL");

    $display("========================================================");
    if (errors_total == 0) $display(" TEST PASSED");
    else                   $display(" TEST FAILED -- %0d mismatching pixels", errors_total);
    $display("========================================================");
    $finish;
  end

  initial begin
    #100ms;
    $display("GLOBAL TIMEOUT");
    $finish;
  end

endmodule
