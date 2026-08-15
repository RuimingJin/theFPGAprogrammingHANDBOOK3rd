-- adt7420_temp_if.vhd
-- ----------------------------------------------------------------------------
--  I2C interface to an Analog Devices ADT7420 temperature sensor, with a
--  true moving average of the last AVG_N readings.
--
--  VHDL port of adt7420_temp_if.sv (see that file for the full commentary).
--
--  Every 1/SAMPLE_HZ seconds it runs one I2C transaction:
--
--      S  addr+W  ptr=0x00  Sr  addr+R  MSB (ack)  LSB (nack)  P
--
--  i.e. it sets the ADT7420 address pointer to the temperature register (0x00)
--  and then reads the two temperature bytes with a repeated start.  The 16-bit
--  result is decoded (13-bit mode: bits[15:3] = signed temperature, [2:0] are
--  flags) and presented two ways:
--
--    * temp_inst - the latest reading
--    * temp_avg  - a true moving average of the last AVG_N (=16) readings
--
--  Both are signed Q8.7: LSB = 1/128 degC, so temperature_degC = value / 128.0.
--
--  The bus is open-drain.  SCL/SDA are exposed as {i,o,t} tri-state triples to
--  drive external IOBUFs (util_ds_buf): connect *_o -> IOBUF.I, *_t -> IOBUF.T,
--  IOBUF.O -> *_i, IOBUF.IO -> package pin.  The core only ever drives '0' or
--  releases (Hi-Z) - board pull-ups provide the '1'.
-- ----------------------------------------------------------------------------
-- Author : Frank Bruno

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

--============================================================================
-- moving_avg - true sliding-window average of the last N signed samples.
-- Keeps a running accumulator and an N-deep sample history so each update is
-- O(1): acc += new - oldest; avg = acc / N.  N should be a power of two.
--============================================================================
entity moving_avg is
  generic (
    N : integer := 16;
    W : integer := 16
  );
  port (
    clk          : in  std_logic;
    rst_n        : in  std_logic;
    sample       : in  signed(W - 1 downto 0);
    sample_valid : in  std_logic;
    avg          : out signed(W - 1 downto 0);
    avg_valid    : out std_logic
  );
end entity moving_avg;

architecture rtl of moving_avg is
  constant LOGN : integer := integer(ceil(log2(real(N))));

  type buf_t is array (0 to N - 1) of signed(W - 1 downto 0);
  signal buffer_r  : buf_t;
  signal acc       : signed(W + LOGN - 1 downto 0);
  signal acc_next  : signed(W + LOGN - 1 downto 0);
begin

  acc_next <= acc + resize(sample, W + LOGN) - resize(buffer_r(N - 1), W + LOGN);

  process (clk, rst_n)
    variable shift_v : signed(W + LOGN - 1 downto 0);
  begin
    if rst_n = '0' then
      acc       <= (others => '0');
      avg       <= (others => '0');
      avg_valid <= '0';
      buffer_r  <= (others => (others => '0'));
    elsif rising_edge(clk) then
      avg_valid <= '0';
      if sample_valid = '1' then
        acc <= acc_next;
        for i in N - 1 downto 1 loop
          buffer_r(i) <= buffer_r(i - 1);
        end loop;
        buffer_r(0) <= sample;
        shift_v     := shift_right(acc_next, LOGN);
        avg         <= shift_v(W - 1 downto 0);
        avg_valid   <= '1';
      end if;
    end if;
  end process;

end architecture rtl;

--============================================================================
-- adt7420_temp_if
--============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity adt7420_temp_if is
  generic (
    CLK_FREQ_HZ : integer                      := 100000000; -- s_axi/logic clock
    I2C_FREQ_HZ : integer                      := 100000;    -- SCL frequency (<=400k)
    SAMPLE_HZ   : integer                      := 4;         -- readings per second
    DEV_ADDR    : std_logic_vector(6 downto 0) := "1001011"; -- ADT7420 I2C address (0x4B)
    AVG_N       : integer                      := 16         -- moving-average depth
  );
  port (
    clk   : in  std_logic;
    rst_n : in  std_logic;

    -- I2C open-drain bus (to external IOBUFs)
    scl_i : in  std_logic;
    scl_o : out std_logic;
    scl_t : out std_logic;
    sda_i : in  std_logic;
    sda_o : out std_logic;
    sda_t : out std_logic;

    -- Temperature outputs: signed, LSB = 1/128 degC
    temp_inst       : out signed(15 downto 0);
    temp_inst_valid : out std_logic;
    temp_avg        : out signed(15 downto 0);
    temp_avg_valid  : out std_logic;

    busy  : out std_logic;  -- high while a transaction is running
    error : out std_logic   -- last transaction was NACKed
  );
end entity adt7420_temp_if;

architecture rtl of adt7420_temp_if is

  constant PTR_TEMP        : std_logic_vector(7 downto 0) := x"00"; -- temperature MSB register
  constant QDIV            : integer := CLK_FREQ_HZ / (4 * I2C_FREQ_HZ);
  constant INTERVAL_CYCLES : integer := CLK_FREQ_HZ / SAMPLE_HZ;

  -- Counter widths and terminal counts, sized so the compares stay clean.
  constant QDIV_W       : integer  := integer(ceil(log2(real(QDIV))));
  constant IVL_W        : integer  := integer(ceil(log2(real(INTERVAL_CYCLES))));
  constant QDIV_MAX     : unsigned(QDIV_W - 1 downto 0) := to_unsigned(QDIV - 1, QDIV_W);
  constant INTERVAL_MAX : unsigned(IVL_W - 1 downto 0)  := to_unsigned(INTERVAL_CYCLES - 1, IVL_W);

  -- Quarter-bit time base.
  signal q_cnt  : unsigned(QDIV_W - 1 downto 0);
  signal q_tick : std_logic;

  -- Synchronize the async SDA input.
  signal sda_meta : std_logic;
  signal sda_sync : std_logic;

  -- Transaction FSM
  type state_t is (
    IDLE, START, WR_AW, ACK_AW, WR_PT, ACK_PT, RSTART,
    WR_AR, ACK_AR, RD_MSB, MACK, RD_LSB, NACK, STOP, UPDATE
  );
  signal state : state_t;

  signal qphase       : unsigned(1 downto 0);          -- quarter within the current bit
  signal bit_cnt      : unsigned(2 downto 0);          -- bits left in the current byte
  signal tx_shift     : std_logic_vector(7 downto 0);  -- MSB-first transmit shifter
  signal rx_shift     : std_logic_vector(7 downto 0);  -- receive shifter
  signal temp_msb     : std_logic_vector(7 downto 0);  -- captured temperature bytes
  signal temp_lsb     : std_logic_vector(7 downto 0);
  signal ack_bit      : std_logic;                     -- last slave ACK (0=ACK, 1=NACK)
  signal abort        : std_logic;                     -- transaction NACKed -> skip UPDATE
  signal interval_cnt : unsigned(IVL_W - 1 downto 0);
  signal sample_valid : std_logic;                     -- 1-cycle strobe: new temp_masked ready

  -- 13-bit-mode decode: keep bits[15:3], zero the flag bits, sign is bit 15.
  signal temp_raw    : std_logic_vector(15 downto 0);
  signal temp_masked : signed(15 downto 0);

  -- SCL/SDA drive (open drain: '1' = release/Hi-Z, '0' = drive low)
  signal scl_hiz : std_logic;
  signal sda_hiz : std_logic;
  signal tx_bit  : std_logic;

begin

  -- The sensor and both outputs never drive the '1' level (open drain).
  scl_o <= '0';
  sda_o <= '0';

  temp_raw    <= temp_msb & temp_lsb;
  temp_masked <= signed(temp_raw(15 downto 3) & "000");

  busy <= '1' when state /= IDLE else '0';

  scl_t  <= scl_hiz;
  sda_t  <= sda_hiz;
  tx_bit <= tx_shift(7);                 -- MSB-first serial output bit

  --------------------------------------------------------------------
  -- Quarter-bit divider
  --------------------------------------------------------------------
  process (clk, rst_n)
  begin
    if rst_n = '0' then
      q_cnt  <= (others => '0');
      q_tick <= '0';
    elsif rising_edge(clk) then
      if state = IDLE then
        q_cnt  <= (others => '0');       -- hold so START begins on a full quarter
        q_tick <= '0';
      elsif q_cnt = QDIV_MAX then
        q_cnt  <= (others => '0');
        q_tick <= '1';
      else
        q_cnt  <= q_cnt + 1;
        q_tick <= '0';
      end if;
    end if;
  end process;

  --------------------------------------------------------------------
  -- SCL/SDA drive (open drain: '1' = release/Hi-Z, '0' = drive low)
  --------------------------------------------------------------------
  process (all)
  begin
    scl_hiz <= '1';                      -- default: bus idle (released high)
    sda_hiz <= '1';
    case state is
      when START =>                      -- SDA falls while SCL high
        sda_hiz <= '1' when qphase = "00" else '0';
        scl_hiz <= '1' when qphase /= "11" else '0';
      when RSTART =>                     -- release SDA, raise SCL, drop SDA
        sda_hiz <= '1' when qphase <= "01" else '0';
        scl_hiz <= '1' when (qphase = "01" or qphase = "10") else '0';
      when STOP =>                       -- SDA rises while SCL high
        sda_hiz <= '1' when qphase >= "10" else '0';
        scl_hiz <= '1' when qphase /= "00" else '0';
      when WR_AW | WR_PT | WR_AR =>      -- drive the current transmit bit
        sda_hiz <= tx_bit;
        scl_hiz <= '1' when (qphase = "01" or qphase = "10") else '0';
      when MACK =>                       -- master ACK after MSB -> drive low
        sda_hiz <= '0';
        scl_hiz <= '1' when (qphase = "01" or qphase = "10") else '0';
      when RD_MSB | RD_LSB |             -- slave drives SDA; release it
           ACK_AW | ACK_PT | ACK_AR |    -- slave drives its ACK; release it
           NACK =>                       -- master NACK after LSB -> release
        sda_hiz <= '1';
        scl_hiz <= '1' when (qphase = "01" or qphase = "10") else '0';
      when others =>                     -- IDLE, UPDATE: idle high
        null;
    end case;
  end process;

  --------------------------------------------------------------------
  -- Main sequencer
  --------------------------------------------------------------------
  process (clk, rst_n)
  begin
    if rst_n = '0' then
      state           <= IDLE;
      qphase          <= "00";
      bit_cnt         <= "000";
      tx_shift        <= (others => '0');
      rx_shift        <= (others => '0');
      temp_msb        <= (others => '0');
      temp_lsb        <= (others => '0');
      ack_bit         <= '0';
      abort           <= '0';
      interval_cnt    <= (others => '0');
      sample_valid    <= '0';
      temp_inst       <= (others => '0');
      temp_inst_valid <= '0';
      error           <= '0';
      sda_meta        <= '1';
      sda_sync        <= '1';
    elsif rising_edge(clk) then
      -- default (pulsed) outputs
      sample_valid    <= '0';
      temp_inst_valid <= '0';

      -- input synchronizer
      sda_meta <= sda_i;
      sda_sync <= sda_meta;

      case state is
        --- wait out the sample interval, then kick off a read -----
        when IDLE =>
          abort <= '0';
          if interval_cnt = INTERVAL_MAX then
            interval_cnt <= (others => '0');
            qphase       <= "00";
            state        <= START;
          else
            interval_cnt <= interval_cnt + 1;
          end if;

        --- publish the decoded sample ----------------------------
        when UPDATE =>
          temp_inst       <= temp_masked;
          temp_inst_valid <= '1';
          sample_valid    <= '1';
          state           <= IDLE;

        --- everything else is I2C, stepped by the quarter tick ----
        when others =>
          if q_tick = '1' then
            qphase <= qphase + 1;

            -- sample SDA mid-SCL-high (q2)
            if qphase = "10" then
              case state is
                when RD_MSB | RD_LSB =>
                  rx_shift <= rx_shift(6 downto 0) & sda_sync;
                when ACK_AW | ACK_PT | ACK_AR =>
                  ack_bit <= sda_sync;
                when others =>
                  null;
              end case;
            end if;

            -- bit / condition boundary (end of q3)
            if qphase = "11" then
              case state is
                when START =>
                  state    <= WR_AW;
                  bit_cnt  <= "111";
                  tx_shift <= DEV_ADDR & "0";      -- write
                when WR_AW =>
                  if bit_cnt = 0 then
                    state <= ACK_AW;
                  else
                    bit_cnt  <= bit_cnt - 1;
                    tx_shift <= tx_shift(6 downto 0) & '0';
                  end if;
                when ACK_AW =>
                  if ack_bit = '1' then
                    abort <= '1';
                    state <= STOP;
                  else
                    state    <= WR_PT;
                    bit_cnt  <= "111";
                    tx_shift <= PTR_TEMP;
                  end if;
                when WR_PT =>
                  if bit_cnt = 0 then
                    state <= ACK_PT;
                  else
                    bit_cnt  <= bit_cnt - 1;
                    tx_shift <= tx_shift(6 downto 0) & '0';
                  end if;
                when ACK_PT =>
                  if ack_bit = '1' then
                    abort <= '1';
                    state <= STOP;
                  else
                    state <= RSTART;
                  end if;
                when RSTART =>
                  state    <= WR_AR;
                  bit_cnt  <= "111";
                  tx_shift <= DEV_ADDR & "1";      -- read
                when WR_AR =>
                  if bit_cnt = 0 then
                    state <= ACK_AR;
                  else
                    bit_cnt  <= bit_cnt - 1;
                    tx_shift <= tx_shift(6 downto 0) & '0';
                  end if;
                when ACK_AR =>
                  if ack_bit = '1' then
                    abort <= '1';
                    state <= STOP;
                  else
                    state   <= RD_MSB;
                    bit_cnt <= "111";
                  end if;
                when RD_MSB =>
                  if bit_cnt = 0 then
                    temp_msb <= rx_shift;
                    state    <= MACK;
                  else
                    bit_cnt <= bit_cnt - 1;
                  end if;
                when MACK =>
                  state   <= RD_LSB;
                  bit_cnt <= "111";
                when RD_LSB =>
                  if bit_cnt = 0 then
                    temp_lsb <= rx_shift;
                    state    <= NACK;
                  else
                    bit_cnt <= bit_cnt - 1;
                  end if;
                when NACK =>
                  state <= STOP;
                when STOP =>
                  error <= abort;
                  if abort = '1' then
                    state <= IDLE;
                  else
                    state <= UPDATE;
                  end if;
                when others =>
                  state <= IDLE;
              end case;
            end if;
          end if;
      end case;
    end if;
  end process;

  --------------------------------------------------------------------
  -- 16-sample moving average of the decoded temperature
  --------------------------------------------------------------------
  u_avg : entity work.moving_avg
    generic map (
      N => AVG_N,
      W => 16
    )
    port map (
      clk          => clk,
      rst_n        => rst_n,
      sample       => temp_masked,
      sample_valid => sample_valid,
      avg          => temp_avg,
      avg_valid    => temp_avg_valid
    );

end architecture rtl;
