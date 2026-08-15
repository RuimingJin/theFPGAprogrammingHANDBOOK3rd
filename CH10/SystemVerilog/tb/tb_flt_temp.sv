`timescale 1ns/10ps
//============================================================================
// tb_flt_temp - self-checking testbench for flt_temp.sv
//
//   Build/run with Verilator (flt_temp uses `const bit`, which iverilog rejects;
//   this testbench itself is plain-Verilog and simulator-agnostic):
//
//     $ verilator --binary --timing -Wno-fatal --top-module tb_flt_temp \
//           tb_flt_temp.sv ../hdl/flt_temp.sv && ./obj_dir/Vtb_flt_temp
//
// flt_temp is a floating-point moving-average + Celsius/Fahrenheit converter.
// It does not compute anything itself: it drives three external Xilinx
// floating-point operators (add/subtract, multiplier, fused-multiply-add) and
// an xpm_fifo_sync, exchanging IEEE-754 single-precision (32-bit) values over
// AXI-Stream-style valid handshakes.  This testbench supplies behavioral models
// of all four so the DUT can be exercised in a plain Verilog simulator.
//
// IEEE-754 single-precision math is done in native `real` (double) via the
// f32<->real helpers below - neither iverilog nor verilator support the 32-bit
// $shortreal system functions, so we unpack/pack the single-precision fields by
// hand.
//
// Each test case resets the DUT and streams a run of one constant temperature.
// For a constant input the moving average equals that input on every sample, so
// fp_temp (degC) must equal the input and fh_temp (degF) must equal
// input*9/5+32, independent of the exact averaging window - a check that does
// not depend on FIFO-window subtleties.
//============================================================================
module tb_flt_temp;

  //--------------------------------------------------------------------------
  // IEEE-754 single-precision  <->  real  helpers
  //--------------------------------------------------------------------------
  function automatic real f32_to_real(input [31:0] b);
    real m; integer e;
    begin
      if (b[30:23] == 8'd0) begin           // zero / subnormal
        m = $itor(b[22:0]) / (2.0**23);  e = -126;
      end else begin                        // normal
        m = 1.0 + $itor(b[22:0]) / (2.0**23);  e = integer'(b[30:23]) - 127;
      end
      f32_to_real = (b[31] ? -1.0 : 1.0) * m * (2.0**e);
    end
  endfunction

  function automatic [31:0] real_to_f32(input real r);
    real a; integer e; logic s; logic [22:0] man; logic [7:0] exp; integer mi;
    begin
      if (r == 0.0) return 32'h0;
      s = (r < 0.0);  a = s ? -r : r;  e = 0;
      while (a >= 2.0) begin a = a/2.0; e = e+1; end
      while (a <  1.0) begin a = a*2.0; e = e-1; end
      mi = $rtoi((a - 1.0)*(2.0**23) + 0.5);        // round to nearest
      if (mi == (1<<23)) begin mi = 0; e = e+1; end  // mantissa rounded up to 2.0
      man = mi[22:0];  exp = 8'(e + 127);
      real_to_f32 = {s, exp, man};
    end
  endfunction

  function automatic real absr(input real x); absr = (x < 0.0) ? -x : x; endfunction

  //--------------------------------------------------------------------------
  // Clock / reset / DUT wiring
  //--------------------------------------------------------------------------
  logic clk = 0;  always #5 clk = ~clk;   // 100 MHz
  logic rst_n = 0;   // active-low reset (asserted = 0)

  logic        fix_temp_tvalid;
  logic [31:0] fix_temp_tdata;

  // addsub
  logic        addsub_a_tvalid, addsub_b_tvalid, addsub_op_tvalid;
  logic [31:0] addsub_a_tdata,  addsub_b_tdata;
  logic [7:0]  addsub_op_tdata;
  logic        addsub_tvalid;
  logic [31:0] addsub_tdata;
  // mult
  logic        mult_a_tvalid, mult_b_tvalid;
  logic [31:0] mult_a_tdata,  mult_b_tdata;
  logic        mult_tvalid;
  logic [31:0] mult_tdata;
  // fused (a*b + c)
  logic        fused_a_tvalid, fused_b_tvalid, fused_c_tvalid;
  logic [31:0] fused_a_tdata,  fused_b_tdata, fused_c_tdata;
  logic        fused_tvalid;
  logic [31:0] fused_tdata;
  // outputs
  logic        fp_temp_tvalid, fh_temp_tvalid;
  logic [31:0] fp_temp_tdata,  fh_temp_tdata;

  flt_temp #(.SMOOTHING(16), .NUM_SEGMENTS(8)) dut (
    .clk, .rst_n,
    .fix_temp_tvalid, .fix_temp_tdata,
    .addsub_a_tvalid, .addsub_a_tdata, .addsub_b_tvalid, .addsub_b_tdata,
    .addsub_op_tvalid, .addsub_op_tdata, .addsub_tvalid, .addsub_tdata,
    .mult_a_tvalid, .mult_a_tdata, .mult_b_tvalid, .mult_b_tdata,
    .mult_tvalid, .mult_tdata,
    .fused_a_tvalid, .fused_a_tdata, .fused_b_tvalid, .fused_b_tdata,
    .fused_c_tvalid, .fused_c_tdata, .fused_tvalid, .fused_tdata,
    .fp_temp_tvalid, .fp_temp_tdata, .fh_temp_tvalid, .fh_temp_tdata
  );

  //--------------------------------------------------------------------------
  // Behavioral floating-point operators (fixed pipeline latency = LAT cycles)
  //--------------------------------------------------------------------------
  localparam int LAT = 3;

  // add / subtract:  op[0]==0 -> a+b,  op[0]==1 -> a-b
  logic [LAT-1:0] as_v;  logic [31:0] as_r [0:LAT-1];
  always @(posedge clk) begin
    as_r[0] <= addsub_op_tdata[0]
             ? real_to_f32(f32_to_real(addsub_a_tdata) - f32_to_real(addsub_b_tdata))
             : real_to_f32(f32_to_real(addsub_a_tdata) + f32_to_real(addsub_b_tdata));
    for (int i = 1; i < LAT; i++) as_r[i] <= as_r[i-1];
    as_v <= {as_v[LAT-2:0], addsub_a_tvalid};
  end
  assign addsub_tvalid = as_v[LAT-1];
  assign addsub_tdata  = as_r[LAT-1];

  // multiplier: a*b
  logic [LAT-1:0] ml_v;  logic [31:0] ml_r [0:LAT-1];
  always @(posedge clk) begin
    ml_r[0] <= real_to_f32(f32_to_real(mult_a_tdata) * f32_to_real(mult_b_tdata));
    for (int i = 1; i < LAT; i++) ml_r[i] <= ml_r[i-1];
    ml_v <= {ml_v[LAT-2:0], mult_a_tvalid};
  end
  assign mult_tvalid = ml_v[LAT-1];
  assign mult_tdata  = ml_r[LAT-1];

  // fused multiply-add: a*b + c
  logic [LAT-1:0] fu_v;  logic [31:0] fu_r [0:LAT-1];
  always @(posedge clk) begin
    fu_r[0] <= real_to_f32(f32_to_real(fused_a_tdata) * f32_to_real(fused_b_tdata)
                           + f32_to_real(fused_c_tdata));
    for (int i = 1; i < LAT; i++) fu_r[i] <= fu_r[i-1];
    fu_v <= {fu_v[LAT-2:0], fused_a_tvalid};
  end
  assign fused_tvalid = fu_v[LAT-1];
  assign fused_tdata  = fu_r[LAT-1];

  //--------------------------------------------------------------------------
  // Capture the DUT results (each valid is a single-cycle pulse)
  //--------------------------------------------------------------------------
  logic [31:0] cap_c, cap_f;
  always @(posedge clk) if (fp_temp_tvalid) cap_c <= fp_temp_tdata;
  always @(posedge clk) if (fh_temp_tvalid) cap_f <= fh_temp_tdata;

  //--------------------------------------------------------------------------
  // Stimulus
  //--------------------------------------------------------------------------
  integer errs = 0;

  task automatic send_sample(input [31:0] d);
    begin
      @(posedge clk);  fix_temp_tvalid = 1'b1;  fix_temp_tdata = d;
      @(posedge clk);  fix_temp_tvalid = 1'b0;
      repeat (40) @(posedge clk);      // let add->sub->mult->fused drain
    end
  endtask

  task automatic run_case(input real degc);
    real exp_c, exp_f, got_c, got_f;  logic [31:0] fb;  integer k;
    begin
      fb = real_to_f32(degc);
      // reset DUT state (clears accumulator / sample & smooth counters)
      rst_n = 1'b0;  repeat (4) @(posedge clk);  rst_n = 1'b1;  @(posedge clk);
      for (k = 0; k < 20; k++) send_sample(fb);   // constant run

      exp_c = degc;
      // expected degF via the DUT's own constants: temp*(9/5) + 32
      exp_f = f32_to_real(real_to_f32(degc*(9.0/5.0) + 32.0));
      got_c = f32_to_real(cap_c);
      got_f = f32_to_real(cap_f);

      if (absr(got_c - exp_c) > 0.05) errs = errs + 1;
      if (absr(got_f - exp_f) > 0.05) errs = errs + 1;

      $display("  in=%7.2f C | degC: got %7.3f exp %7.3f | degF: got %7.3f exp %7.3f  %s",
               degc, got_c, exp_c, got_f, exp_f,
               (absr(got_c-exp_c)<=0.05 && absr(got_f-exp_f)<=0.05) ? "ok" : "MISMATCH");
    end
  endtask

  // Ideal moving average of the last min(count,SMOOTHING) samples, kept in the
  // testbench so we can check the DUT tracks a changing input, not just a
  // constant.  This is what exposed the FIFO sliding-window bug.
  real win [$];

  function automatic real ideal_avg;
    real s;  int i;
    begin s = 0; for (i = 0; i < win.size(); i++) s += win[i]; ideal_avg = s / win.size(); end
  endfunction

  task automatic run_ramp;
    real v, exp_c, got_c;  integer k;
    begin
      win = {};
      rst_n = 1'b0;  repeat (4) @(posedge clk);  rst_n = 1'b1;  @(posedge clk);
      $display("  ramp (checks a true 16-sample moving average once the window fills):");
      for (k = 1; k <= 24; k++) begin
        v = 20.0 + k;                                  // 21, 22, ... 44
        win.push_back(v);  if (win.size() > 16) win.pop_front();
        send_sample(real_to_f32(v));
        exp_c = ideal_avg();
        got_c = f32_to_real(cap_c);
        if (absr(got_c - exp_c) > 0.05) errs = errs + 1;
        $display("    n=%2d in=%6.2f  degC: got %7.3f  expect %7.3f  %s",
                 k, v, got_c, exp_c, (absr(got_c-exp_c) <= 0.05) ? "ok" : "MISMATCH");
      end
    end
  endtask

  initial begin
    fix_temp_tvalid = 0;  fix_temp_tdata = 0;
    rst_n = 0;  repeat (10) @(posedge clk);

    $display("tb_flt_temp: constant-temperature checks");
    run_case(  0.0);
    run_case( 25.0);
    run_case( 37.5);
    run_case(100.0);
    run_case(-10.0);

    run_ramp();

    $display("tb_flt_temp: %s (errs=%0d)", errs==0 ? "PASS" : "FAIL", errs);
    $finish;
  end

  initial begin #500000 $display("TIMEOUT"); $finish; end

endmodule

//============================================================================
// Behavioral xpm_fifo_sync - synchronous FIFO, "std" read mode.
//   * dout updates the cycle AFTER rd_en (registered read data)
//   * reads while empty and writes while full are ignored (matches Xilinx)
// Only the ports flt_temp connects are modeled; the rest are dangling stubs so
// the DUT's named port map elaborates unchanged.
//============================================================================
module xpm_fifo_sync #(
    parameter FIFO_WRITE_DEPTH = 32,
    parameter WRITE_DATA_WIDTH = 32,
    parameter READ_DATA_WIDTH  = 32
) (
    input  wire                          sleep,
    input  wire                          rst,
    input  wire                          wr_clk,
    input  wire                          wr_en,
    input  wire [WRITE_DATA_WIDTH-1:0]   din,
    output wire                          full,
    output wire                          prog_full,
    output wire [$clog2(FIFO_WRITE_DEPTH):0] wr_data_count,
    output wire                          overflow,
    output wire                          wr_rst_busy,
    output wire                          almost_full,
    output wire                          wr_ack,
    input  wire                          rd_en,
    output reg  [READ_DATA_WIDTH-1:0]    dout,
    output wire                          empty,
    output wire                          prog_empty,
    output wire [$clog2(FIFO_WRITE_DEPTH):0] rd_data_count,
    output wire                          underflow,
    output wire                          rd_rst_busy,
    output wire                          almost_empty,
    output wire                          data_valid,
    input  wire                          injectsbiterr,
    input  wire                          injectdbiterr,
    output wire                          sbiterr,
    output wire                          dbiterr
);
  localparam DEPTH = FIFO_WRITE_DEPTH;
  reg [WRITE_DATA_WIDTH-1:0] mem [0:DEPTH-1];
  integer wp = 0, rp = 0, occ = 0;
  logic do_wr, do_rd;

  always @(posedge wr_clk) begin
    if (rst) begin
      wp <= 0;  rp <= 0;  occ <= 0;
    end else begin
      do_wr = wr_en && (occ < DEPTH);
      do_rd = rd_en && (occ > 0);
      if (do_wr) begin mem[wp] <= din;  wp <= (wp + 1) % DEPTH; end
      if (do_rd) begin dout <= mem[rp]; rp <= (rp + 1) % DEPTH; end
      occ <= occ + (do_wr ? 1 : 0) - (do_rd ? 1 : 0);
    end
  end

  assign empty       = (occ == 0);
  assign full        = (occ == DEPTH);
  assign almost_empty= (occ <= 1);
  assign almost_full = (occ >= DEPTH-1);
  assign prog_empty  = empty;
  assign prog_full   = full;
  assign overflow    = 1'b0;
  assign underflow   = 1'b0;
  assign wr_ack      = 1'b0;
  assign wr_rst_busy = 1'b0;
  assign rd_rst_busy = 1'b0;
  assign data_valid  = 1'b0;
  assign sbiterr     = 1'b0;
  assign dbiterr     = 1'b0;
  assign wr_data_count = occ[$clog2(FIFO_WRITE_DEPTH):0];
  assign rd_data_count = occ[$clog2(FIFO_WRITE_DEPTH):0];
endmodule
