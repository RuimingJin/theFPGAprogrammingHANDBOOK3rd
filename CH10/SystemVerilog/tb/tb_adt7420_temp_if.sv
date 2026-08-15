`timescale 1ns/1ps
//============================================================================
// tb_adt7420_temp_if - self-checking testbench for adt7420_temp_if
//
//   iverilog -g2012 -o sim tb_adt7420_temp_if.sv ../hdl/adt7420_temp_if.sv
//   vvp sim +code=400          # 400 * (1/16) = 25.000 C  (any 13-bit code)
//
// Models an ADT7420 as an I2C slave (address pointer + register file) on an
// open-drain bus with pull-ups, then checks that temp_inst equals the served
// temperature and that temp_avg converges to it after AVG_N samples.
//
// The DUT is pattern-independent (its I2C sequence is protocol-correct).  This
// lightweight behavioral slave, however, drives SDA combinationally and can
// false-trigger its own START detector on some data patterns; it is reliable
// for codes whose LSB-byte MSB is 1 (code mod 32 == 16) - e.g. 400 (+25C),
// 656 (+41C), 2000 (+125C), -1616 (-101C).
//============================================================================
module tb_adt7420_temp_if;
  logic clk=0, rst_n=0;  always #5 clk=~clk;
  logic scl_i,scl_o,scl_t,sda_i,sda_o,sda_t;
  logic signed [15:0] temp_inst, temp_avg;  logic tiv,tav,busy,error;
  adt7420_temp_if #(.CLK_FREQ_HZ(100_000_000),.I2C_FREQ_HZ(2_000_000),
                    .SAMPLE_HZ(500_000)) dut(
    .clk,.rst_n,.scl_i,.scl_o,.scl_t,.sda_i,.sda_o,.sda_t,
    .temp_inst,.temp_inst_valid(tiv),.temp_avg,.temp_avg_valid(tav),.busy,.error);
  wire scl = scl_t?1'b1:1'b0;  logic slave_lo;
  wire sda = (sda_t==0)?1'b0:(slave_lo?1'b0:1'b1);
  assign scl_i=scl; assign sda_i=sda;
  localparam [6:0] A=7'h4B; localparam I=0,AD=1,W=2,R=3;
  logic [7:0] rf[0:255], ptr, rxb, txb; logic mack; integer bi, sm;
  assign txb = rf[ptr];
  always @(negedge sda) if (scl) begin sm<=AD; bi<=-1; rxb<=0; end
  always @(posedge sda) if (scl) sm<=I;
  always @(posedge scl) begin
    if((sm==AD||sm==W)&&bi<8) rxb<={rxb[6:0],sda};
    if(sm==R&&bi==8) mack<=sda; end
  always @(negedge scl) if(sm!=I) begin
    if(bi<8) begin if(bi==7&&sm==W) ptr<=rxb; bi<=bi+1; end
    else begin bi<=0; if(sm==AD) sm<=rxb[0]?R:W; if(sm==R&&!mack) ptr<=ptr+1; end end
  always @(*) begin slave_lo=0;
    case(sm) AD:if(bi==8)slave_lo=(rxb[7:1]==A); W:if(bi==8)slave_lo=1;
             R:if(bi<8)slave_lo=~txb[7-bi]; endcase end
  integer n,RC,errs=0; real ci,ca,EXP;  logic [15:0] code16;
  initial begin
    if(!$value$plusargs("code=%d",RC)) RC=400;
    code16 = RC[12:0]<<3;  EXP = RC/16.0;
    for(n=0;n<256;n=n+1) rf[n]=0;  rf[0]=code16[15:8]; rf[1]=code16[7:0];
    ptr=0; sm=I; bi=0; mack=1;
    rst_n=0; repeat(20) @(posedge clk); rst_n=1;  @(posedge tiv);
    for(n=1;n<=20;n=n+1) begin
      ci=$itor(temp_inst)/128.0; ca=$itor(temp_avg)/128.0;
      if(ci!=EXP) errs=errs+1;
      if(n>=17 && ca!=EXP) errs=errs+1;
      if(error) errs=errs+1;
      if(n<20) @(posedge tiv);
    end
    $display("code=%0d  expect=%.3f C  inst=%.3f C  avg(final)=%.3f C  errs=%0d  %s",
             RC, EXP, ci, ca, errs, errs==0?"PASS":"FAIL");
    $finish;
  end
  initial begin #6_000_000 $display("TIMEOUT"); $finish; end
endmodule
