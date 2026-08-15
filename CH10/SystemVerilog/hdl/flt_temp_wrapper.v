`timescale 1ns/10ps
module flt_temp_wrapper
  #
  (
   parameter  SMOOTHING    = 16,
   parameter  NUM_SEGMENTS = 8
   )
  (
   input         clk, // 100Mhz clock
   input         rst_n, // Reset - active Low

   // data from fix to float
   input         fix_temp_tvalid,
   input [31:0]  fix_temp_tdata,

   // Addsub interface
   output        addsub_a_tvalid,
   output [31:0] addsub_a_tdata,
   output        addsub_b_tvalid,
   output [31:0] addsub_b_tdata,
   output        addsub_op_tvalid,
   output [7:0]  addsub_op_tdata,
   input         addsub_tvalid,
   input [31:0]  addsub_tdata,

   // Multiplier interface
   output        mult_a_tvalid,
   output [31:0] mult_a_tdata,
   output        mult_b_tvalid,
   output [31:0] mult_b_tdata,
   input         mult_tvalid,
   input [31:0]  mult_tdata,

   // Fused Multiplier-Add interface
   output        fused_a_tvalid,
   output [31:0] fused_a_tdata,
   output        fused_b_tvalid,
   output [31:0] fused_b_tdata,
   output        fused_c_tvalid,
   output [31:0] fused_c_tdata,
   input         fused_tvalid,
   input [31:0]  fused_tdata,

   // Float to fixed
   output        fp_temp_tvalid,
   output [31:0] fp_temp_tdata,
   output        fh_temp_tvalid,
   output [31:0] fh_temp_tdata
   );

  flt_temp
    #
    (
     .SMOOTHING    (16),
     .NUM_SEGMENTS (8)
     )
  flt_temp
    (
     .clk              (clk),
     .rst_n            (rst_n),

     // data from fix to float
     .fix_temp_tvalid  (fix_temp_tvalid),
     .fix_temp_tdata   (fix_temp_tdata),

     // Addsub interface
     .addsub_a_tvalid  (addsub_a_tvalid),
     .addsub_a_tdata   (addsub_a_tdata),
     .addsub_b_tvalid  (addsub_b_tvalid),
     .addsub_b_tdata   (addsub_b_tdata),
     .addsub_op_tvalid (addsub_op_tvalid),
     .addsub_op_tdata  (addsub_op_tdata),
     .addsub_tvalid    (addsub_tvalid),
     .addsub_tdata     (addsub_tdata),

     // Multiplier interface
     .mult_a_tvalid    (mult_a_tvalid),
     .mult_a_tdata     (mult_a_tdata),
     .mult_b_tvalid    (mult_b_tvalid),
     .mult_b_tdata     (mult_b_tdata),
     .mult_tvalid      (mult_tvalid),
     .mult_tdata       (mult_tdata),

     // Fused Multiplier-Add interface
     .fused_a_tvalid   (fused_a_tvalid),
     .fused_a_tdata    (fused_a_tdata),
     .fused_b_tvalid   (fused_b_tvalid),
     .fused_b_tdata    (fused_b_tdata),
     .fused_c_tvalid   (fused_c_tvalid),
     .fused_c_tdata    (fused_c_tdata),
     .fused_tvalid     (fused_tvalid),
     .fused_tdata      (fused_tdata),

     // Float to fixed
     .fp_temp_tvalid   (fp_temp_tvalid),
     .fp_temp_tdata    (fp_temp_tdata),
     .fh_temp_tvalid   (fh_temp_tvalid),
     .fh_temp_tdata    (fh_temp_tdata)
     );
endmodule // spi_temp
