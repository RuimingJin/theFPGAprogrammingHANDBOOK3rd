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
module adt7420_axil
  #
  (
   parameter int         CLK_FREQ_HZ = 100_000_000, // = AXI clock
   parameter int         I2C_FREQ_HZ = 100_000,
   parameter int         SAMPLE_HZ = 4,
   parameter logic [6:0] DEV_ADDR = 7'h4B,
   parameter int         AVG_N = 16,
   parameter int         C_S_AXI_ADDR_WIDTH = 4
   )
  (
   // AXI4-Lite slave
   input logic                          s_axi_aclk,
   input logic                          s_axi_aresetn,

   input logic [C_S_AXI_ADDR_WIDTH-1:0] s_axi_awaddr,
   input logic                          s_axi_awvalid,
   output logic                         s_axi_awready,
   input logic [31:0]                   s_axi_wdata,
   input logic [3:0]                    s_axi_wstrb,
   input logic                          s_axi_wvalid,
   output logic                         s_axi_wready,
   output logic [1:0]                   s_axi_bresp,
   output logic                         s_axi_bvalid,
   input logic                          s_axi_bready,

   input logic [C_S_AXI_ADDR_WIDTH-1:0] s_axi_araddr,
   input logic                          s_axi_arvalid,
   output logic                         s_axi_arready,
   output logic [31:0]                  s_axi_rdata,
   output logic [1:0]                   s_axi_rresp,
   output logic                         s_axi_rvalid,
   input logic                          s_axi_rready,

   output logic                         temp_inst_valid,
   output logic signed [15:0]           temp_inst,
   input                                fx_inst_valid,
   input signed [15:0]                  fx_inst,
   input                                fh_inst_valid,
   input signed [15:0]                  fh_inst,

   // I2C open-drain bus (to external IOBUFs)
   input logic                          scl_i,
   output logic                         scl_o,
   output logic                         scl_t,
   input logic                          sda_i,
   output logic                         sda_o,
   output logic                         sda_t
   );

    //--------------------------------------------------------------------
    // Sensor interface (runs on the AXI clock / reset)
    //--------------------------------------------------------------------
    logic signed [15:0] temp_avg;
    logic               temp_avg_valid;
    logic               busy, error;

    adt7420_temp_if #(
        .CLK_FREQ_HZ (CLK_FREQ_HZ),
        .I2C_FREQ_HZ (I2C_FREQ_HZ),
        .SAMPLE_HZ   (SAMPLE_HZ),
        .DEV_ADDR    (DEV_ADDR),
        .AVG_N       (AVG_N)
    ) u_sensor (
        .clk             (s_axi_aclk),
        .rst_n           (s_axi_aresetn),
        .scl_i           (scl_i),
        .scl_o           (scl_o),
        .scl_t           (scl_t),
        .sda_i           (sda_i),
        .sda_o           (sda_o),
        .sda_t           (sda_t),
        .temp_inst       (temp_inst),
        .temp_inst_valid (temp_inst_valid),
        .temp_avg        (temp_avg),
        .temp_avg_valid  (temp_avg_valid),
        .busy            (busy),
        .error           (error)
    );

    //--------------------------------------------------------------------
    // Capture the latest measurements + a sample counter
    //--------------------------------------------------------------------
    logic signed [15:0] inst_r, avg_r, fh_r, fx_r;
    logic [15:0]        sample_cnt;

    always_ff @(posedge s_axi_aclk or negedge s_axi_aresetn) begin
        if (!s_axi_aresetn) begin
            inst_r     <= '0;
            avg_r      <= '0;
            sample_cnt <= '0;
        end else begin
            if (temp_inst_valid) begin
                inst_r     <= temp_inst;
                sample_cnt <= sample_cnt + 1'b1;
            end
          if (temp_avg_valid) avg_r <= temp_avg;
          if (fx_inst_valid)  fx_r <= fx_inst;
          if (fh_inst_valid)  fh_r <= fh_inst;
        end
    end

    //--------------------------------------------------------------------
    // Read-data mux (registers are word-aligned; decode araddr[4:2])
    //--------------------------------------------------------------------
  logic [31:0] inst_ext, avg_ext, fh_ext, fx_ext;
    assign inst_ext = {{16{inst_r[15]}}, inst_r};   // sign-extend to 32 bits
    assign avg_ext  = {{16{avg_r[15]}},  avg_r};
    assign fh_ext  = {{16{fh_r[15]}},  fh_r};
    assign fx_ext  = {{16{fx_r[15]}},  fx_r};

    logic [31:0] rd_mux;
    always_comb begin
        case (s_axi_araddr[4:2])
            3'd0:    rd_mux = inst_ext;                            // TEMP_INST
            3'd1:    rd_mux = avg_ext;                             // TEMP_AVG
            3'd2:    rd_mux = {sample_cnt, 14'b0, error, busy};    // STATUS
            3'd3:    rd_mux = 32'h0000_7420;                       // ID
          3'd4: rd_mux = fx_ext;
          3'd5: rd_mux = fh_ext;
            default: rd_mux = 32'h0000_0000;
        endcase
    end

    //--------------------------------------------------------------------
    // AXI4-Lite read channel
    //--------------------------------------------------------------------
    always_ff @(posedge s_axi_aclk or negedge s_axi_aresetn) begin
        if (!s_axi_aresetn) begin
            s_axi_arready <= 1'b0;
            s_axi_rvalid  <= 1'b0;
            s_axi_rresp   <= 2'b00;
            s_axi_rdata   <= 32'b0;
        end else begin
            s_axi_arready <= 1'b0;                       // default: 1-cycle accept
            if (s_axi_arvalid && !s_axi_arready && !s_axi_rvalid) begin
                s_axi_arready <= 1'b1;                   // accept address
                s_axi_rdata   <= rd_mux;                 // latch data for this addr
                s_axi_rresp   <= 2'b00;                  // OKAY
                s_axi_rvalid  <= 1'b1;
            end else if (s_axi_rvalid && s_axi_rready) begin
                s_axi_rvalid  <= 1'b0;                   // read data accepted
            end
        end
    end

    //--------------------------------------------------------------------
    // AXI4-Lite write channel (no writable registers; just answer OKAY)
    //--------------------------------------------------------------------
    always_ff @(posedge s_axi_aclk or negedge s_axi_aresetn) begin
        if (!s_axi_aresetn) begin
            s_axi_awready <= 1'b0;
            s_axi_wready  <= 1'b0;
            s_axi_bvalid  <= 1'b0;
            s_axi_bresp   <= 2'b00;
        end else begin
            s_axi_awready <= 1'b0;
            s_axi_wready  <= 1'b0;
            if (s_axi_awvalid && s_axi_wvalid && !s_axi_bvalid &&
                !s_axi_awready && !s_axi_wready) begin
                s_axi_awready <= 1'b1;                   // accept address + data
                s_axi_wready  <= 1'b1;
                s_axi_bvalid  <= 1'b1;                   // OKAY response
                s_axi_bresp   <= 2'b00;
            end else if (s_axi_bvalid && s_axi_bready) begin
                s_axi_bvalid  <= 1'b0;
            end
        end
    end

endmodule
