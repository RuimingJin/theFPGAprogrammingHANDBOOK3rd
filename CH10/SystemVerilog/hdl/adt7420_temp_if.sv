`timescale 1ns/1ps
//============================================================================
// adt7420_temp_if
//----------------------------------------------------------------------------
// Clean-slate interface to an Analog Devices ADT7420 I2C temperature sensor.
//
// Every 1/SAMPLE_HZ seconds it runs one I2C transaction:
//
//     S  addr+W  ptr=0x00  Sr  addr+R  MSB (ack)  LSB (nack)  P
//
// i.e. it sets the ADT7420 address pointer to the temperature register (0x00)
// and then reads the two temperature bytes with a repeated start.  The 16-bit
// result is decoded (13-bit mode: bits[15:3] = signed temperature, [2:0] are
// flags) and presented two ways:
//
//   * temp_inst - the latest reading
//   * temp_avg  - a true moving average of the last AVG_N (=16) readings
//
// Both are signed Q8.7: LSB = 1/128 degC, so temperature_degC = value / 128.0.
//
// The bus is open-drain.  SCL/SDA are exposed as {i,o,t} tri-state triples to
// drive external IOBUFs (util_ds_buf): connect *_o -> IOBUF.I, *_t -> IOBUF.T,
// IOBUF.O -> *_i, IOBUF.IO -> package pin.  The core only ever drives '0' or
// releases (Hi-Z) - board pull-ups provide the '1'.
//============================================================================
module adt7420_temp_if #(
    parameter int         CLK_FREQ_HZ = 100_000_000, // s_axi/logic clock
    parameter int         I2C_FREQ_HZ = 100_000,     // SCL frequency (<=400k)
    parameter int         SAMPLE_HZ   = 4,           // readings per second
    parameter logic [6:0] DEV_ADDR    = 7'h4B,       // ADT7420 I2C address
    parameter int         AVG_N       = 16           // moving-average depth
)(
    input  logic               clk,
    input  logic               rst_n,

    // I2C open-drain bus (to external IOBUFs)
    input  logic               scl_i,
    output logic               scl_o,
    output logic               scl_t,
    input  logic               sda_i,
    output logic               sda_o,
    output logic               sda_t,

    // Temperature outputs: signed, LSB = 1/128 degC
    output logic signed [15:0] temp_inst,
    output logic               temp_inst_valid,
    output logic signed [15:0] temp_avg,
    output logic               temp_avg_valid,

    output logic               busy,      // high while a transaction is running
    output logic               error      // last transaction was NACKed
);

    localparam logic [7:0] PTR_TEMP        = 8'h00;   // temperature MSB register
    localparam int         QDIV            = CLK_FREQ_HZ / (4*I2C_FREQ_HZ);
    localparam int         INTERVAL_CYCLES = CLK_FREQ_HZ / SAMPLE_HZ;

    // Counter widths and terminal counts, sized so the compares stay clean.
    localparam int QDIV_W = $clog2(QDIV);
    localparam int IVL_W  = $clog2(INTERVAL_CYCLES);
    localparam logic [QDIV_W-1:0] QDIV_MAX     = QDIV_W'(QDIV - 1);
    localparam logic [IVL_W-1:0]  INTERVAL_MAX = IVL_W'(INTERVAL_CYCLES - 1);

    // The sensor and both outputs never drive the '1' level (open drain).
    assign scl_o = 1'b0;
    assign sda_o = 1'b0;

    //--------------------------------------------------------------------
    // Quarter-bit time base.  Each I2C bit is 4 quarters (q0..q3):
    //   q0: SCL low  - change SDA        q2: SCL high - sample SDA
    //   q1: SCL high                     q3: SCL low  - hold
    // The divider is held in reset while IDLE so the first START aligns.
    //--------------------------------------------------------------------
    logic [QDIV_W-1:0] q_cnt;
    logic                    q_tick;

    //--------------------------------------------------------------------
    // Synchronize the async SDA input.
    //--------------------------------------------------------------------
    logic sda_meta, sda_sync;

    //--------------------------------------------------------------------
    // Transaction FSM
    //--------------------------------------------------------------------
    typedef enum logic [3:0] {
        IDLE, START, WR_AW, ACK_AW, WR_PT, ACK_PT, RSTART,
        WR_AR, ACK_AR, RD_MSB, MACK, RD_LSB, NACK, STOP, UPDATE
    } state_t;
    state_t state;

    logic [1:0] qphase;                 // quarter within the current bit
    logic [2:0] bit_cnt;                // bits left in the current byte
    logic [7:0] tx_shift;               // MSB-first transmit shifter
    logic [7:0] rx_shift;               // receive shifter
    logic [7:0] temp_msb, temp_lsb;     // captured temperature bytes
    logic       ack_bit;                // last slave ACK (0=ACK, 1=NACK)
    logic       abort;                  // transaction NACKed -> skip UPDATE
    logic [IVL_W-1:0] interval_cnt;
    logic       sample_valid;           // 1-cycle strobe: new temp_masked ready

    // 13-bit-mode decode: keep bits[15:3], zero the flag bits, sign is bit 15.
    logic [15:0]        temp_raw;
    logic signed [15:0] temp_masked;
    assign temp_raw    = {temp_msb, temp_lsb};
    assign temp_masked = signed'({temp_raw[15:3], 3'b000});

    assign busy = (state != IDLE);

    //--------------------------------------------------------------------
    // Quarter-bit divider
    //--------------------------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            q_cnt  <= '0;
            q_tick <= 1'b0;
        end else if (state == IDLE) begin
            q_cnt  <= '0;               // hold so START begins on a full quarter
            q_tick <= 1'b0;
        end else if (q_cnt == QDIV_MAX) begin
            q_cnt  <= '0;
            q_tick <= 1'b1;
        end else begin
            q_cnt  <= q_cnt + 1'b1;
            q_tick <= 1'b0;
        end
    end

    //--------------------------------------------------------------------
    // SCL/SDA drive (open drain: '1' = release/Hi-Z, '0' = drive low)
    //--------------------------------------------------------------------
    logic scl_hiz, sda_hiz;
    logic tx_bit;
    assign scl_t  = scl_hiz;
    assign sda_t  = sda_hiz;
    assign tx_bit = tx_shift[7];        // MSB-first serial output bit

    always_comb begin
        scl_hiz = 1'b1;                 // default: bus idle (released high)
        sda_hiz = 1'b1;
        case (state)
            START: begin                // SDA falls while SCL high
                sda_hiz = (qphase == 2'd0);
                scl_hiz = (qphase != 2'd3);
            end
            RSTART: begin               // release SDA, raise SCL, drop SDA
                sda_hiz = (qphase <= 2'd1);
                scl_hiz = (qphase == 2'd1) || (qphase == 2'd2);
            end
            STOP: begin                 // SDA rises while SCL high
                sda_hiz = (qphase >= 2'd2);
                scl_hiz = (qphase != 2'd0);
            end
            WR_AW, WR_PT, WR_AR: begin  // drive the current transmit bit
                sda_hiz = tx_bit;
                scl_hiz = (qphase == 2'd1) || (qphase == 2'd2);
            end
            MACK: begin                 // master ACK after MSB -> drive low
                sda_hiz = 1'b0;
                scl_hiz = (qphase == 2'd1) || (qphase == 2'd2);
            end
            RD_MSB, RD_LSB,             // slave drives SDA; release it
            ACK_AW, ACK_PT, ACK_AR,     // slave drives its ACK; release it
            NACK: begin                 // master NACK after LSB -> release
                sda_hiz = 1'b1;
                scl_hiz = (qphase == 2'd1) || (qphase == 2'd2);
            end
            default: ;                  // IDLE, UPDATE: idle high
        endcase
    end

    //--------------------------------------------------------------------
    // Main sequencer
    //--------------------------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state           <= IDLE;
            qphase          <= 2'd0;
            bit_cnt         <= 3'd0;
            tx_shift        <= 8'd0;
            rx_shift        <= 8'd0;
            temp_msb        <= 8'd0;
            temp_lsb        <= 8'd0;
            ack_bit         <= 1'b0;
            abort           <= 1'b0;
            interval_cnt    <= '0;
            sample_valid    <= 1'b0;
            temp_inst       <= '0;
            temp_inst_valid <= 1'b0;
            error           <= 1'b0;
            sda_meta        <= 1'b1;
            sda_sync        <= 1'b1;
        end else begin
            // default (pulsed) outputs
            sample_valid    <= 1'b0;
            temp_inst_valid <= 1'b0;

            // input synchronizer
            sda_meta <= sda_i;
            sda_sync <= sda_meta;

            case (state)
                //--- wait out the sample interval, then kick off a read -----
                IDLE: begin
                    abort <= 1'b0;
                    if (interval_cnt == INTERVAL_MAX) begin
                        interval_cnt <= '0;
                        qphase       <= 2'd0;
                        state        <= START;
                    end else begin
                        interval_cnt <= interval_cnt + 1'b1;
                    end
                end

                //--- publish the decoded sample ----------------------------
                UPDATE: begin
                    temp_inst       <= temp_masked;
                    temp_inst_valid <= 1'b1;
                    sample_valid    <= 1'b1;
                    state           <= IDLE;
                end

                //--- everything else is I2C, stepped by the quarter tick ----
                default: begin
                    if (q_tick) begin
                        qphase <= qphase + 2'd1;

                        // sample SDA mid-SCL-high (q2)
                        if (qphase == 2'd2) begin
                            case (state)
                                RD_MSB, RD_LSB:
                                    rx_shift <= {rx_shift[6:0], sda_sync};
                                ACK_AW, ACK_PT, ACK_AR:
                                    ack_bit  <= sda_sync;
                                default: ;
                            endcase
                        end

                        // bit / condition boundary (end of q3)
                        if (qphase == 2'd3) begin
                            case (state)
                                START: begin
                                    state    <= WR_AW;
                                    bit_cnt  <= 3'd7;
                                    tx_shift <= {DEV_ADDR, 1'b0}; // write
                                end
                                WR_AW:
                                    if (bit_cnt == 0) state <= ACK_AW;
                                    else begin
                                        bit_cnt  <= bit_cnt - 1'b1;
                                        tx_shift <= tx_shift << 1;
                                    end
                                ACK_AW:
                                    if (ack_bit) begin abort <= 1'b1; state <= STOP; end
                                    else begin
                                        state    <= WR_PT;
                                        bit_cnt  <= 3'd7;
                                        tx_shift <= PTR_TEMP;
                                    end
                                WR_PT:
                                    if (bit_cnt == 0) state <= ACK_PT;
                                    else begin
                                        bit_cnt  <= bit_cnt - 1'b1;
                                        tx_shift <= tx_shift << 1;
                                    end
                                ACK_PT:
                                    if (ack_bit) begin abort <= 1'b1; state <= STOP; end
                                    else state <= RSTART;
                                RSTART: begin
                                    state    <= WR_AR;
                                    bit_cnt  <= 3'd7;
                                    tx_shift <= {DEV_ADDR, 1'b1}; // read
                                end
                                WR_AR:
                                    if (bit_cnt == 0) state <= ACK_AR;
                                    else begin
                                        bit_cnt  <= bit_cnt - 1'b1;
                                        tx_shift <= tx_shift << 1;
                                    end
                                ACK_AR:
                                    if (ack_bit) begin abort <= 1'b1; state <= STOP; end
                                    else begin state <= RD_MSB; bit_cnt <= 3'd7; end
                                RD_MSB:
                                    if (bit_cnt == 0) begin
                                        temp_msb <= rx_shift;
                                        state    <= MACK;
                                    end else bit_cnt <= bit_cnt - 1'b1;
                                MACK: begin
                                    state   <= RD_LSB;
                                    bit_cnt <= 3'd7;
                                end
                                RD_LSB:
                                    if (bit_cnt == 0) begin
                                        temp_lsb <= rx_shift;
                                        state    <= NACK;
                                    end else bit_cnt <= bit_cnt - 1'b1;
                                NACK:
                                    state <= STOP;
                                STOP: begin
                                    error <= abort;
                                    state <= abort ? IDLE : UPDATE;
                                end
                                default: state <= IDLE;
                            endcase
                        end
                    end
                end
            endcase
        end
    end

    //--------------------------------------------------------------------
    // 16-sample moving average of the decoded temperature
    //--------------------------------------------------------------------
    moving_avg #(.N(AVG_N), .W(16)) u_avg (
        .clk          (clk),
        .rst_n        (rst_n),
        .sample       (temp_masked),
        .sample_valid (sample_valid),
        .avg          (temp_avg),
        .avg_valid    (temp_avg_valid)
    );

endmodule

//============================================================================
// moving_avg - true sliding-window average of the last N signed samples.
// Keeps a running accumulator and an N-deep sample history so each update is
// O(1): acc += new - oldest; avg = acc / N.  N should be a power of two.
//============================================================================
module moving_avg #(
    parameter int N = 16,
    parameter int W = 16
)(
    input  logic                clk,
    input  logic                rst_n,
    input  logic signed [W-1:0] sample,
    input  logic                sample_valid,
    output logic signed [W-1:0] avg,
    output logic                avg_valid
);
    localparam int LOGN = $clog2(N);

    logic signed [W-1:0]      buffer [N];
    logic signed [W+LOGN-1:0] acc;
    logic signed [W+LOGN-1:0] acc_next;
    integer i;

    always_comb acc_next = acc + (W+LOGN)'(sample) - (W+LOGN)'(buffer[N-1]);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            acc       <= '0;
            avg       <= '0;
            avg_valid <= 1'b0;
            for (i = 0; i < N; i++) buffer[i] <= '0;
        end else begin
            avg_valid <= 1'b0;
            if (sample_valid) begin
                acc <= acc_next;
                for (i = N-1; i > 0; i--) buffer[i] <= buffer[i-1];
                buffer[0] <= sample;
                avg       <= W'(acc_next >>> LOGN);
                avg_valid <= 1'b1;
            end
        end
    end
endmodule
