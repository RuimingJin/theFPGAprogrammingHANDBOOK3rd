-- image_filter_core.vhd
-- ------------------------------------
-- 3x3 sliding-window filter over two line buffers
-- ------------------------------------
-- Author : Frank Bruno
--
-- A direct RTL transcription of the HLS window_filter stage, including its
-- iteration space, which is what makes the two implementations bit-identical.
--
-- The loop runs (height+1) x (width+1) times. A pixel is consumed whenever
-- (r < height and c < width) and produced whenever (r >= 1 and c >= 1); both
-- totals come to exactly width*height, which keeps the input and output FIFOs
-- balanced. The window centre win11 at step (r,c) holds input pixel (r-1,c-1),
-- so the output written at step (r,c) is output pixel (r-1, c-1).
--
-- Pipeline, one step per cycle when not stalled:
--   S0  counters; present column address to the line buffers; pop input
--   S1  line-buffer data arrives; shift the window; write the buffers back
--   S2  compute the Sobel partial sums gx / gy
--   S3  absolute value, clamp, mode select, push output
--
-- All four stages share one enable, so they advance together or not at all.

LIBRARY IEEE;
USE IEEE.std_logic_1164.all;
USE IEEE.numeric_std.all;

entity image_filter_core is
  generic (
    MAX_WIDTH : integer := 1920
  );
  port (
    clk        : in  std_logic;
    rst_n      : in  std_logic;

    start      : in  std_logic;
    img_width  : in  std_logic_vector(15 downto 0);
    img_height : in  std_logic_vector(15 downto 0);
    mode       : in  std_logic_vector(31 downto 0);
    done       : out std_logic;

    s_valid    : in  std_logic;
    s_data     : in  std_logic_vector(7 downto 0);
    s_ready    : out std_logic;

    m_valid    : out std_logic;
    m_data     : out std_logic_vector(7 downto 0);
    m_ready    : in  std_logic
  );
end entity image_filter_core;

architecture rtl of image_filter_core is

  type lb_t is array (0 to MAX_WIDTH-1) of std_logic_vector(7 downto 0);
  signal lb0 : lb_t := (others => (others => '0'));
  signal lb1 : lb_t := (others => (others => '0'));
  attribute ram_style : string;
  attribute ram_style of lb0 : signal is "block";
  attribute ram_style of lb1 : signal is "block";

  signal lb0_dout, lb1_dout : std_logic_vector(7 downto 0) := (others => '0');

  signal w_r, h_r  : unsigned(15 downto 0) := (others => '0');
  signal mode_r    : std_logic_vector(31 downto 0) := (others => '0');

  signal running   : std_logic := '0';
  signal s0_v, s1_v, s2_v, s3_v : std_logic := '0';
  signal r_cnt, c_cnt : unsigned(15 downto 0) := (others => '0');

  signal s0_need_in, s0_rd, s0_prod : std_logic;
  signal s1_rd, s1_prod, s1_border  : std_logic := '0';
  signal s1_newpx : std_logic_vector(7 downto 0) := (others => '0');
  signal s1_c     : unsigned(15 downto 0) := (others => '0');

  signal s2_prod, s2_border : std_logic := '0';
  signal s2_gray  : std_logic_vector(7 downto 0) := (others => '0');
  signal s2_gx, s2_gy : signed(12 downto 0) := (others => '0');

  signal s3_prod  : std_logic := '0';

  signal en        : std_logic;
  signal last_step : std_logic;

  signal win00, win01, win02 : std_logic_vector(7 downto 0) := (others => '0');
  signal win10, win11, win12 : std_logic_vector(7 downto 0) := (others => '0');
  signal win20, win21, win22 : std_logic_vector(7 downto 0) := (others => '0');

  signal n00, n01, n02, n10, n11, n12, n20, n21, n22 : std_logic_vector(7 downto 0);

  signal col_l, col_rt, row_t, row_b : unsigned(11 downto 0);
  signal abs_gx, abs_gy : unsigned(12 downto 0);
  signal mag            : unsigned(13 downto 0);
  signal sobel_v, sel_v : std_logic_vector(7 downto 0);

begin

  s0_need_in <= '1' when (r_cnt < h_r and c_cnt < w_r) else '0';
  s0_rd      <= '1' when (c_cnt < w_r) else '0';
  s0_prod    <= '1' when (r_cnt >= 1 and c_cnt >= 1) else '0';
  last_step  <= '1' when (r_cnt = h_r and c_cnt = w_r) else '0';

  en <= '1' when (((s0_v = '0' or s0_need_in = '0') or s_valid = '1') and
                  ((s3_v = '0' or s3_prod = '0')    or m_ready = '1'))
        else '0';

  -- Both of these are single-cycle strobes qualified by `en`, not held
  -- AXI-style valid/ready. The pipeline can stall for a reason unrelated to the
  -- consumer -- S0 waiting on an input pixel -- and a held m_valid would make
  -- the downstream FIFO latch the same output pixel again every stalled cycle.
  s_ready <= en and s0_v and s0_need_in;
  m_valid <= en and s3_v and s3_prod;

  -- The C shifts the window left first, then fills column 2. Because every
  -- right-hand side here reads the pre-shift registers, the "past the right
  -- edge" branch reduces to simply holding column 2.
  n00 <= win01;  n01 <= win02;
  n02 <= lb0_dout when s1_rd = '1' else win02;
  n10 <= win11;  n11 <= win12;
  n12 <= lb1_dout when s1_rd = '1' else win12;
  n20 <= win21;  n21 <= win22;
  n22 <= s1_newpx when s1_rd = '1' else win22;

  -- S0: counters
  process (clk) begin
    if rising_edge(clk) then
      if rst_n = '0' then
        running <= '0';
        s0_v    <= '0';
        r_cnt   <= (others => '0');
        c_cnt   <= (others => '0');
        w_r     <= (others => '0');
        h_r     <= (others => '0');
        mode_r  <= (others => '0');
        done    <= '0';
      else
        done <= '0';
        if start = '1' and running = '0' then
          w_r    <= unsigned(img_width);
          h_r    <= unsigned(img_height);
          mode_r <= mode;
          r_cnt  <= (others => '0');
          c_cnt  <= (others => '0');
          if unsigned(img_width) /= 0 and unsigned(img_height) /= 0 then
            s0_v <= '1';
          else
            s0_v <= '0';
          end if;
          running <= '1';
        elsif running = '1' then
          if en = '1' and s0_v = '1' then
            if last_step = '1' then
              s0_v <= '0';
            elsif c_cnt = w_r then
              c_cnt <= (others => '0');
              r_cnt <= r_cnt + 1;
            else
              c_cnt <= c_cnt + 1;
            end if;
          end if;
          if s0_v = '0' and s1_v = '0' and s2_v = '0' and s3_v = '0' then
            running <= '0';
            done    <= '1';
          end if;
        end if;
      end if;
    end if;
  end process;

  -- line-buffer read
  process (clk) begin
    if rising_edge(clk) then
      if en = '1' then
        lb0_dout <= lb0(to_integer(c_cnt(10 downto 0)));
        lb1_dout <= lb1(to_integer(c_cnt(10 downto 0)));
      end if;
    end if;
  end process;

  -- S0 -> S1
  process (clk) begin
    if rising_edge(clk) then
      if rst_n = '0' then
        s1_v <= '0';
      elsif en = '1' then
        s1_v    <= s0_v;
        s1_rd   <= s0_rd;
        s1_prod <= s0_prod;
        s1_c    <= c_cnt;
        if s0_need_in = '1' then
          s1_newpx <= s_data;
        else
          s1_newpx <= (others => '0');
        end if;
        -- Sobel is undefined on the 1px frame; the C emits black there
        if r_cnt = 1 or r_cnt = h_r or c_cnt = 1 or c_cnt = w_r then
          s1_border <= '1';
        else
          s1_border <= '0';
        end if;
      end if;
    end if;
  end process;

  -- S1: window shift and line-buffer writeback
  process (clk) begin
    if rising_edge(clk) then
      if rst_n = '0' then
        win00 <= (others => '0'); win01 <= (others => '0'); win02 <= (others => '0');
        win10 <= (others => '0'); win11 <= (others => '0'); win12 <= (others => '0');
        win20 <= (others => '0'); win21 <= (others => '0'); win22 <= (others => '0');
      elsif en = '1' and s1_v = '1' then
        win00 <= n00; win01 <= n01; win02 <= n02;
        win10 <= n10; win11 <= n11; win12 <= n12;
        win20 <= n20; win21 <= n21; win22 <= n22;
      end if;
    end if;
  end process;

  process (clk) begin
    if rising_edge(clk) then
      if en = '1' and s1_v = '1' and s1_rd = '1' then
        lb0(to_integer(s1_c(10 downto 0))) <= lb1_dout;   -- row r-1 -> r-2
        lb1(to_integer(s1_c(10 downto 0))) <= s1_newpx;   -- row r   -> r-1
      end if;
    end if;
  end process;

  -- S1 -> S2: Sobel partial sums from the post-shift window
  col_l  <= resize(unsigned(n00), 12) + (resize(unsigned(n10), 12) sll 1) + resize(unsigned(n20), 12);
  col_rt <= resize(unsigned(n02), 12) + (resize(unsigned(n12), 12) sll 1) + resize(unsigned(n22), 12);
  row_t  <= resize(unsigned(n00), 12) + (resize(unsigned(n01), 12) sll 1) + resize(unsigned(n02), 12);
  row_b  <= resize(unsigned(n20), 12) + (resize(unsigned(n21), 12) sll 1) + resize(unsigned(n22), 12);

  process (clk) begin
    if rising_edge(clk) then
      if rst_n = '0' then
        s2_v <= '0';
      elsif en = '1' then
        s2_v      <= s1_v;
        s2_prod   <= s1_prod;
        s2_border <= s1_border;
        s2_gray   <= n11;
        s2_gx     <= signed("0" & col_rt) - signed("0" & col_l);
        s2_gy     <= signed("0" & row_b)  - signed("0" & row_t);
      end if;
    end if;
  end process;

  -- S2 -> S3: absolute value, clamp, mode select
  abs_gx <= unsigned(-s2_gx) when s2_gx(12) = '1' else unsigned(s2_gx);
  abs_gy <= unsigned(-s2_gy) when s2_gy(12) = '1' else unsigned(s2_gy);
  mag    <= ("0" & abs_gx) + ("0" & abs_gy);

  sobel_v <= (others => '0') when s2_border = '1' else
             x"FF"           when mag(13 downto 8) /= "000000" else
             std_logic_vector(mag(7 downto 0));

  -- Compare the whole word, not just the low bits: the C tests "== MODE_GRAY"
  -- then "== MODE_INVERT" and falls through to Sobel for every other value, so
  -- mode 4 must give Sobel, not grayscale.
  sel_v <= s2_gray when mode_r = x"00000000" else
           std_logic_vector(to_unsigned(255, 8) - unsigned(s2_gray))
                    when mode_r = x"00000002" else
           sobel_v;

  process (clk) begin
    if rising_edge(clk) then
      if rst_n = '0' then
        s3_v <= '0';
      elsif en = '1' then
        s3_v    <= s2_v;
        s3_prod <= s2_prod;
        m_data  <= sel_v;
      end if;
    end if;
  end process;

end architecture rtl;
