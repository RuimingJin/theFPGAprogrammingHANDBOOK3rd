`timescale 1ns/10ps
module adt7420_i2c_mod
  #
  (
   parameter  DEVICE_ID    = "TEMP",
   parameter  SMOOTHING    = 16,
   parameter  INTERVAL     = 1000000000,
   parameter  CLK_PER      = 10
   )
  (
   // AXI lite interface for register acceess
   input               s_axi_aclk,
   input               s_axi_aresetn,
   input [21:0]        s_axi_awaddr,
   input               s_axi_awvalid,
   output logic        s_axi_awready,
   input [31:0]        s_axi_wdata,
   input [3:0]         s_axi_wstrb,
   input               s_axi_wvalid,
   output logic        s_axi_wready,
   output logic [1:0]  s_axi_bresp,
   output logic        s_axi_bvalid,
   input               s_axi_bready,
   input [21:0]        s_axi_araddr,
   input               s_axi_arvalid,
   output logic        s_axi_arready,
   output logic [31:0] s_axi_rdata,
   output logic [1:0]  s_axi_rresp,
   output logic        s_axi_rvalid,
   input               s_axi_rready,

   // Temperature Sensor Interface
   input wire          TMP_SCL_i,
   output wire         TMP_SCL_o,
   output wire         TMP_SCL_t,
   input wire          TMP_SDA_i,
   output wire         TMP_SDA_o,
   output wire         TMP_SDA_t,
   inout wire          TMP_INT,
   inout wire          TMP_CT,

   output logic        fix_temp_tvalid,
   output logic [15:0] fix_temp_tdata,

   input wire          flt_temp_tvalid,
   input wire [15:0]   flt_temp_tdata
   );

  localparam TIME_1SEC   = int'(INTERVAL/CLK_PER); // Clock ticks in 1 sec
  localparam TIME_THDSTA = int'(600/CLK_PER);
  localparam TIME_TSUSTA = int'(600/CLK_PER);
  localparam TIME_THIGH  = int'(600/CLK_PER);
  localparam TIME_TLOW   = int'(1300/CLK_PER);
  localparam TIME_TSUDAT = int'(20/CLK_PER);
  localparam TIME_TSUSTO = int'(600/CLK_PER);
  localparam TIME_THDDAT = int'(30/CLK_PER);
  localparam I2C_ADDR = 7'b1001011; // 0x4B
  localparam I2CBITS = 1 + // start
                       7 + // 7 bits for address
                       1 + // 1 bit for read
                       1 + // 1 bit for ack back
                       8 + // 8 bits upper data
                       1 + // 1 bit for ack
                       8 + // 8 bits lower data
                       1 + // 1 bit for ack
                       1 + 1;  // 1 bit for stop

  // ADT7420 register pointer for the temperature MSB register.  The sensor's
  // address pointer must be set to this value before reading; a bare read
  // returns whatever register the pointer last landed on (often 0x0000).
  localparam logic [7:0] PTR_TEMP = 8'h00;
  // Terminal bit_count for each phase.  The pointer-write phase must stop the
  // instant the pointer byte is ACKed - clocking any further would auto-
  // increment the ADT7420 pointer and write into the config registers.  The
  // read phase keeps the original frame length.
  localparam WR_LAST = 18;
  localparam RD_LAST = I2CBITS;

  localparam logic [7:0] ADDR_DEVICE_ID = 8'h00;
  localparam logic [7:0] ADDR_VERSION   = 8'h04;
  localparam logic [7:0] ADDR_STATUS    = 8'h10;
  localparam logic [7:0] ADDR_TEMP      = 8'h14;
  localparam logic [7:0] ADDR_TEMP_SMOOTH = 8'h18;
  localparam logic [7:0] ADDR_TEMP_FLOAT  = 8'h1c;

  typedef enum bit [1:0] {RD_IDLE, RD_WAIT, RD_W4RREADY} axil_rd_cs_t;
  typedef enum bit [1:0] {WR_IDLE, WR_W4ADDR, WR_W4DATA, WR_BRESP} axil_cs_t;
  axil_rd_cs_t     axil_rd_cs;
  axil_cs_t        axil_cs;

  logic [7:0]  rd_addr;
  logic [31:0] read_data;
  logic [31:0] axil_din;
  logic [3:0]  axil_be;
  logic        axil_we;
  logic [7:0]  axil_addr;
  logic                            sda_en;
  logic                            scl_en;
  logic [I2CBITS-1:0]              i2c_data;
  logic [I2CBITS-1:0]              i2c_en;
  logic [I2CBITS-1:0]              i2c_capt;
  logic [$clog2(TIME_1SEC)-1:0]    counter;
  logic                            counter_reset;
  logic [$clog2(I2CBITS)-1:0]      bit_count;
  logic [15:0]                     temp_data;
  logic                            capture_en;
  logic                            convert;
  logic [31:0]                     temp_count;
  logic                            wr_phase;   // 1 = writing pointer, 0 = reading temperature

  //assign TMP_SCL = scl_en ? 'z : '0;
  //assign TMP_SDA = sda_en ? 'z : '0;

  assign TMP_SCL_o = '0;
  assign TMP_SCL_t = scl_en;
  assign TMP_SDA_o = '0;
  assign TMP_SDA_t = sda_en;

  typedef enum bit [3:0]
               {
                IDLE,
                START,
                TLOW,
                TSU,
                THIGH,
                THD,
                PSTO,    // stop setup: pull SDA low while SCL is low
                TSTO,
                TBUF     // bus-free time between the pointer-write and read
                } spi_t;

  spi_t spi_state;

  assign capture_en = i2c_capt[I2CBITS - bit_count - 1];

  initial begin
    scl_en          = '0;
    sda_en          = '0;
    counter_reset   = '0;
    counter         = '0;
    bit_count       = '0;
    temp_count      = '0;
    wr_phase        = '0;
  end

  always @(posedge s_axi_aclk) begin
    scl_en                     <= '1;
    sda_en                     <= ~i2c_en[I2CBITS - bit_count - 1] |
                                  i2c_data[I2CBITS - bit_count - 1];
    if (counter_reset) counter <= '0;
    else counter <= counter + 1'b1;
    counter_reset <= '0;
    convert       <= '0;

    case (spi_state)
      IDLE: begin
        // Every cycle runs two transactions: first a pointer write
        //   START, addr+W, <ACK>, pointer(0x00), <ACK>, STOP
        // then (after a bus-free gap) the temperature read.
        wr_phase  <= '1;
        i2c_data  <= {1'b0, I2C_ADDR, 1'b0, 1'b1, PTR_TEMP, 1'b1, 11'b0};
        i2c_en    <= {1'b1, 7'h7F,    1'b1, 1'b0, 8'hFF,    1'b0, 11'b0};
        i2c_capt  <= '0; // nothing is captured while writing the pointer
        bit_count <= '0;
        sda_en    <= '1; // Force to 1 in the beginning.

        if (counter == TIME_1SEC) begin
          temp_data     <= '0;
          spi_state     <= START;
          counter_reset <= '1;
          sda_en        <= '0; // Drop the data
        end
      end
      START: begin
        sda_en <= '0; // Drop the data
        // Hold clock low for thd:sta
        if (counter == TIME_THDSTA) begin
          counter_reset   <= '1;
          scl_en          <= '0; // Drop the clock
          spi_state       <= TLOW;
        end
      end
      TLOW: begin
        scl_en            <= '0; // Drop the clock
        if (counter == TIME_TLOW) begin
          bit_count     <= bit_count + 1'b1;
          counter_reset <= '1;
          spi_state     <= TSU;
        end
      end
      TSU: begin
        scl_en            <= '0; // Drop the clock
        if (counter == TIME_TSUSTA) begin
          counter_reset <= '1;
          spi_state     <= THIGH;
        end
      end
      THIGH: begin
        scl_en          <= '1; // Raise the clock
        if (counter == TIME_THIGH) begin
          if (capture_en) temp_data <= temp_data << 1 | TMP_SDA_i;
          counter_reset <= '1;
          spi_state     <= THD;
        end
      end
      THD: begin
        scl_en            <= '0; // Drop the clock
        if (counter == TIME_THDDAT) begin
          counter_reset <= '1;
          // Each phase stops after its own last bit; PSTO/TSTO form the STOP.
          spi_state     <= (bit_count == (wr_phase ? WR_LAST : RD_LAST)) ?
                           PSTO : TLOW;
        end
      end
      PSTO: begin
        // Stop setup: with SCL low, pull SDA low so it can later rise while SCL
        // is high (a low->high SDA edge while SCL high is the STOP condition).
        scl_en <= '0; // keep SCL low
        sda_en <= '0; // drive SDA low
        if (counter == TIME_TSUSTA) begin
          counter_reset <= '1;
          spi_state     <= TSTO;
        end
      end
      TSTO: begin
        // Raise SCL with SDA held low, then release SDA high => STOP.
        scl_en <= '1; // SCL high
        sda_en <= '0; // SDA low, ready to rise
        if (counter == TIME_TSUSTO) begin
          counter_reset <= '1;
          sda_en        <= '1; // release SDA high => STOP
          if (wr_phase) begin
            // Pointer write finished.  Load the read frame and take the bus-free
            // gap before issuing a fresh START for the read.
            wr_phase  <= '0;
            i2c_data  <= {1'b0, I2C_ADDR, 1'b1, 1'b0, 8'b00, 1'b0, 8'b00, 1'b1, 1'b0, 1'b1};
            i2c_en    <= {1'b1, 7'h7F,    1'b1, 1'b0, 8'b00, 1'b1, 8'b00, 1'b1, 1'b1, 1'b1};
            i2c_capt  <= {1'b0, 7'h00,    1'b0, 1'b0, 8'hFF, 1'b0, 8'hFF, 1'b0, 1'b0, 1'b0};
            bit_count <= '0;
            spi_state <= TBUF;
          end else begin
            // Read finished; publish the sample.
            convert    <= '1;
            temp_count <= temp_count + 1'b1;
            spi_state  <= IDLE;
          end
        end
      end
      TBUF: begin
        // Bus-free time between the two transactions, then a fresh START.
        scl_en <= '1; // SCL idle high
        sda_en <= '1; // SDA idle high
        if (counter == TIME_TLOW) begin
          counter_reset <= '1;
          sda_en        <= '0; // drop SDA while SCL high => (re)START
          spi_state     <= START;
        end
      end
    endcase
  end

  assign fix_temp_tvalid = convert;
  assign fix_temp_tdata = temp_data >> 3; // lop off lower three unused bits

  logic signed [15:0] smooth_data;
  logic               smooth_convert;
  logic signed [15:0] smooth_capt;

  localparam          SMOOTHING_SHIFT = $clog2(SMOOTHING);
  logic [SMOOTHING_SHIFT:0] smooth_count;
  logic signed [15:0]       dout;
  logic                     rden, rden_del;
  logic signed [31:0]       accumulator;
  logic signed [15:0]       temperature;
  logic signed [15:0]       fp_temp;

  initial begin
    rden         = '0;
    smooth_count = '0;
    accumulator  = '0;
  end

  always @(posedge s_axi_aclk) begin
    rden           <= '0;
    rden_del       <= rden;
    smooth_convert <= '0;
    if (convert) begin
      smooth_count              <= smooth_count + 1'b1;
      accumulator               <= accumulator + signed'({temp_data[15:3], 3'b0});
    end else if (smooth_count == SMOOTHING+1) begin
      rden                    <= '1;
      smooth_count            <= smooth_count - 1'b1;
      accumulator             <= accumulator - signed'(dout);
    end else if (rden) begin
      smooth_data             <= accumulator >>> SMOOTHING_SHIFT;
      smooth_convert          <= '1;
    end
  end

  xpm_fifo_sync
    #
    (
     .FIFO_WRITE_DEPTH       (SMOOTHING),
     .WRITE_DATA_WIDTH       (16),
     .READ_MODE              ("FWFT")
     )
  u_xpm_fifo_sync
    (
     .sleep                  ('0),
     .rst                    ('0),

     .wr_clk                 (s_axi_aclk),
     .wr_en                  (convert),
     .din                    ({temp_data[15:3], 3'b0}),
     .full                   (),
     .prog_full              (),
     .wr_data_count          (),
     .overflow               (),
     .wr_rst_busy            (),
     .almost_full            (),
     .wr_ack                 (),

     .rd_en                  (rden),
     .dout                   (dout),
     .empty                  (),
     .prog_empty             (),
     .rd_data_count          (),
     .underflow              (),
     .rd_rst_busy            (),
     .almost_empty           (),
     .data_valid             (),

     .injectsbiterr          ('0),
     .injectdbiterr          ('0),
     .sbiterr                (),
     .dbiterr                ()
     );

  // AXI Read Channel
  always @(posedge s_axi_aclk) begin
    s_axi_arready <= '1;
    s_axi_rvalid  <= '0;
    s_axi_rresp   <= '0;

    case (axil_rd_cs)
      RD_IDLE: begin
        if (s_axi_arvalid) begin
          s_axi_arready <= '0;
          rd_addr       <= s_axi_araddr[7:0];
          axil_rd_cs    <= RD_WAIT;
        end
      end
      RD_WAIT: begin
        s_axi_arready <= '0;
        axil_rd_cs    <= RD_W4RREADY;
      end
      RD_W4RREADY: begin
        s_axi_arready <= '0;
        s_axi_rdata   <= read_data;
        s_axi_rvalid  <= '1;
        if (s_axi_rready && s_axi_rvalid) begin
          s_axi_arready <= '1;
          s_axi_rvalid  <= '0;
          axil_rd_cs    <= RD_IDLE;
        end
      end
    endcase // case (axil_rd_cs)
    if (~s_axi_aresetn) begin
      axil_rd_cs <= RD_IDLE;
    end
  end

  // AXI Write Channel
  always @(posedge s_axi_aclk) begin
    axil_we       <= '0;
    s_axi_bvalid  <= '0;
    s_axi_bresp   <= '0; // OKAY

    case (axil_cs)
      WR_IDLE: begin
        s_axi_awready <= '1;
        s_axi_wready  <= '1;
        case ({s_axi_awvalid, s_axi_wvalid})
          2'b11: begin
            s_axi_awready <= '0;
            s_axi_wready  <= '0;
            axil_addr     <= s_axi_awaddr[7:0];
            axil_we       <= '1;
            s_axi_bvalid  <= '1;
            axil_cs       <= WR_BRESP;
            axil_din      <= s_axi_wdata;
            axil_be       <= s_axi_wstrb;
          end
          2'b10: begin
            // Address only
            s_axi_awready <= '0;
            axil_addr     <= s_axi_awaddr[7:0];
            axil_cs       <= WR_W4DATA;
          end
          2'b01: begin
            s_axi_wready <= '0;
            axil_we      <= '1;
            axil_din     <= s_axi_wdata;
            axil_be      <= s_axi_wstrb;
            axil_cs      <= WR_W4ADDR;
          end
        endcase
      end
      WR_W4DATA: begin
        if (s_axi_wvalid) begin
          s_axi_wready <= '0;
          axil_we      <= '1;
          s_axi_bvalid <= '1;
          axil_din     <= s_axi_wdata;
          axil_be      <= s_axi_wstrb;
          axil_cs      <= WR_BRESP;
        end
      end
      WR_W4ADDR: begin
        if (s_axi_awvalid) begin
          s_axi_awready <= '0;
          s_axi_bvalid  <= '1;
          axil_addr     <= s_axi_awaddr[7:0];
          axil_cs       <= WR_BRESP;
        end
      end
      WR_BRESP: begin
        s_axi_awready <= '0;
        s_axi_wready  <= '0;
        s_axi_bvalid  <= '1;
        if (s_axi_bready) begin
          s_axi_awready <= '1;
          s_axi_wready  <= '1;
          s_axi_bvalid  <= '0;
          axil_cs       <= WR_IDLE;
        end
      end
    endcase
    if (~s_axi_aresetn) begin
      axil_cs <= WR_IDLE;
    end
  end // always @ (posedge axil_clk)

  /*
  always @(posedge s_axi_aclk) begin
    if (axil_we) begin
      casez (axil_addr[7:0])
      endcase // casez (axil_addr[7:0])
    end // if (axil_we)
  end // always @ (posedge s_axi_aclk)
*/

  always @(posedge s_axi_aclk) begin
    if (smooth_convert) smooth_capt <= smooth_data;
    if (convert) temperature <= temp_data;
    if (flt_temp_tvalid) fp_temp <= flt_temp_tdata;
    read_data <= '0;
    casez (rd_addr[7:0])
      ADDR_DEVICE_ID  : read_data <= DEVICE_ID;
      ADDR_VERSION    : read_data <= 32'h0000_0000;
      ADDR_STATUS     : read_data <= temp_count;
      ADDR_TEMP       : read_data <= {16'b0, temperature};
      ADDR_TEMP_SMOOTH: read_data <= {16'b0, smooth_capt};
      ADDR_TEMP_FLOAT : read_data <= {16'b0, fp_temp};
      default         : read_data <= 32'h0000_0000;
    endcase // casez (rd_addr[7:0])
  end

endmodule // spi_temp
