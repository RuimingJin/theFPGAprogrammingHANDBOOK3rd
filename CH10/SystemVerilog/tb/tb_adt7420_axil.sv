`timescale 1ns/1ps
module tb_axil;
  logic clk=0, rstn=0; always #5 clk=~clk;
  logic [3:0] awaddr=0, araddr=0; logic awvalid=0, wvalid=0, bready=0, arvalid=0, rready=0;
  logic [31:0] wdata=0; logic [3:0] wstrb=4'hF;
  logic awready, wready, bvalid, arready, rvalid; logic [1:0] bresp, rresp; logic [31:0] rdata;
  logic scl_i,scl_o,scl_t,sda_i,sda_o,sda_t;
  adt7420_axil #(.CLK_FREQ_HZ(100_000_000),.I2C_FREQ_HZ(2_000_000),
                 .SAMPLE_HZ(500_000),.DEV_ADDR(7'h4B),.AVG_N(16)) dut(
    .s_axi_aclk(clk),.s_axi_aresetn(rstn),
    .s_axi_awaddr(awaddr),.s_axi_awvalid(awvalid),.s_axi_awready(awready),
    .s_axi_wdata(wdata),.s_axi_wstrb(wstrb),.s_axi_wvalid(wvalid),.s_axi_wready(wready),
    .s_axi_bresp(bresp),.s_axi_bvalid(bvalid),.s_axi_bready(bready),
    .s_axi_araddr(araddr),.s_axi_arvalid(arvalid),.s_axi_arready(arready),
    .s_axi_rdata(rdata),.s_axi_rresp(rresp),.s_axi_rvalid(rvalid),.s_axi_rready(rready),
    .scl_i,.scl_o,.scl_t,.sda_i,.sda_o,.sda_t);
  wire scl = scl_t?1'b1:1'b0; logic slave_lo;
  wire sda = (sda_t==0)?1'b0:(slave_lo?1'b0:1'b1);
  assign scl_i=scl; assign sda_i=sda;
  localparam [6:0] A=7'h4B; localparam I=0,AD=1,W=2,R=3;
  logic [7:0] rf[0:255], ptr, rxb, txb; logic mack; integer bi, sm;
  assign txb=rf[ptr];
  always @(negedge sda) if(scl) begin sm<=AD; bi<=-1; rxb<=0; end
  always @(posedge sda) if(scl) sm<=I;
  always @(posedge scl) begin
    if((sm==AD||sm==W)&&bi<8) rxb<={rxb[6:0],sda}; if(sm==R&&bi==8) mack<=sda; end
  always @(negedge scl) if(sm!=I) begin
    if(bi<8) begin if(bi==7&&sm==W) ptr<=rxb; bi<=bi+1; end
    else begin bi<=0; if(sm==AD) sm<=rxb[0]?R:W; if(sm==R&&!mack) ptr<=ptr+1; end end
  always @(*) begin slave_lo=0;
    case(sm) AD:if(bi==8)slave_lo=(rxb[7:1]==A); W:if(bi==8)slave_lo=1;
             R:if(bi<8)slave_lo=~txb[7-bi]; endcase end
  task axi_read(input [3:0] a, output [31:0] d); begin
    @(posedge clk); araddr<=a; arvalid<=1; rready<=1;
    wait(arready); @(posedge clk); arvalid<=0; wait(rvalid); d=rdata; @(posedge clk); rready<=0;
  end endtask
  integer errs=0; logic [31:0] d; real c;
  initial begin
    for(bi=0;bi<256;bi=bi+1) rf[bi]=0; rf[0]=8'h0C; rf[1]=8'h80;  // 25.000 C
    ptr=0; sm=I; bi=0; mack=1;
    rstn=0; repeat(20) @(posedge clk); rstn=1;
    repeat(20) @(posedge dut.temp_inst_valid);
    axi_read(4'h0,d); c=$itor($signed(d))/128.0;
    $display("0x00 TEMP_INST=0x%08h  %.3f C", d, c); if(c!=25.0) errs=errs+1;
    axi_read(4'h4,d); c=$itor($signed(d))/128.0;
    $display("0x04 TEMP_AVG =0x%08h  %.3f C", d, c); if(c!=25.0) errs=errs+1;
    axi_read(4'h8,d);
    $display("0x08 STATUS   =0x%08h  busy=%b err=%b samples=%0d", d,d[0],d[1],d[31:16]);
    if(d[1]!=0||d[31:16]==0) errs=errs+1;
    axi_read(4'hC,d); $display("0x0C ID      =0x%08h", d); if(d!=32'h7420) errs=errs+1;
    @(posedge clk); awaddr<=0; awvalid<=1; wdata<=32'hDEAD; wvalid<=1; bready<=1;
    wait(bvalid); @(posedge clk); if(bresp!=0) errs=errs+1;
    awvalid<=0; wvalid<=0; @(posedge clk); bready<=0;
    if(errs==0) $display("*** AXI-LITE PASS ***"); else $display("*** FAIL: %0d ***", errs);
    $finish;
  end
  initial begin #8_000_000 $display("TIMEOUT"); $finish; end
endmodule
