#!/usr/bin/env python3
"""
Grove 16x2 LCD (AiP31068L) on a Xilinx AXI IIC core in the PL, driven from PYNQ.

Talks to the AXI IIC IP directly via MMIO using its dynamic controller
(START/STOP markers in the TX FIFO), and brings up the AiP31068L / ST7032-
compatible panel with its extended instruction set (booster + follower +
contrast) so text is actually visible.

Verified working config: contrast 0x38, 1/5 bias.
"""
class AxiIic:
    """Minimal AXI IIC master-transmit driver (dynamic controller mode)."""

    # Register offsets from the IP base address (Xilinx PG090)
    ISR     = 0x020    # Interrupt Status Register
    SOFTR   = 0x040    # Soft Reset (write 0x0A)
    CR      = 0x100    # Control Register
    SR      = 0x104    # Status Register
    TX_FIFO = 0x108    # Transmit FIFO

    # Control Register bits
    CR_EN           = 0x01
    CR_TXFIFO_RESET = 0x02

    # Status Register bits
    SR_BB = 0x04       # bus busy

    # Interrupt Status bits
    ISR_TX_ERROR = 0x02   # INT(1): slave NACK in master-transmit

    # Dynamic-mode TX FIFO markers
    START = 0x100
    STOP  = 0x200

    def __init__(self, mmio):
        self.mmio = mmio
        self.reset()

    def reset(self):
        self.mmio.write(self.SOFTR, 0x0A)               # soft reset (also clears BB)
        time.sleep(0.001)
        self.mmio.write(self.CR, self.CR_TXFIFO_RESET)  # flush TX FIFO
        self.mmio.write(self.CR, self.CR_EN)            # enable, clear reset

    def _wait_bus_idle(self, timeout=0.2):
        t0 = time.time()
        while self.mmio.read(self.SR) & self.SR_BB:
            if time.time() - t0 > timeout:
                raise TimeoutError("AXI IIC bus stuck busy (check wiring / pull-ups)")

    def write_bytes(self, addr7, data):
        """Write `data` (list of ints) to 7-bit `addr7` in one transaction.
        Raises IOError if the slave NACKs any byte."""
        self._wait_bus_idle()
        self.mmio.write(self.ISR, self.mmio.read(self.ISR))   # clear stale flags
        self.mmio.write(self.TX_FIFO, self.START | (addr7 << 1))
        n = len(data)
        for i, b in enumerate(data):
            word = b & 0xFF
            if i == n - 1:
                word |= self.STOP
            self.mmio.write(self.TX_FIFO, word)
        time.sleep(0.001)
        self._wait_bus_idle()
        if self.mmio.read(self.ISR) & self.ISR_TX_ERROR:
            self.reset()                                       # return to clean state
            raise IOError(f"I2C NACK from 0x{addr7:02X} "
                          f"(device not responding / bus fault)")


class GroveLCD:
    """Grove 16x2 LCD (AiP31068L, ST7032-compatible) at I2C address 0x3E."""

    ADDR = 0x3E

    def __init__(self, iic, contrast=0x38):
        self.iic = iic
        self._init(contrast)

    # --- low-level framing: 0x80 -> command follows, 0x40 -> data follows ---
    def _cmd(self, c):
        self.iic.write_bytes(self.ADDR, [0x80, c])

    def _char(self, c):
        self.iic.write_bytes(self.ADDR, [0x40, c])

    def _init(self, contrast):
        time.sleep(0.05)
        self._cmd(0x38)                                   # function set: 8-bit, 2-line, IS=0
        self._cmd(0x39)                                   # function set: IS=1 (extended)
        self._cmd(0x14)                                   # OSC / bias (1/5); use 0x1C for 1/4 bias
        self._cmd(0x70 | (contrast & 0x0F))               # contrast, low 4 bits
        self._cmd(0x50 | 0x04 | ((contrast >> 4) & 0x03)) # booster ON + contrast high 2 bits
        self._cmd(0x6C)                                   # follower ON, amplifier ratio
        time.sleep(0.30)                                  # booster/follower settle (>200 ms)
        self._cmd(0x38)                                   # back to normal instruction set
        self._cmd(0x0C)                                   # display ON, cursor off, blink off
        self.clear()
        self._cmd(0x06)                                   # entry mode: increment

    def set_contrast(self, v):
        """Retune contrast live (v in 0x00..0x3F)."""
        self._cmd(0x39)
        self._cmd(0x70 | (v & 0x0F))
        self._cmd(0x50 | 0x04 | ((v >> 4) & 0x03))
        self._cmd(0x38)

    def clear(self):
        self._cmd(0x01)
        time.sleep(0.002)

    def set_cursor(self, col, row):
        self._cmd(0x80 | (col | (0x40 if row else 0x00)))

    def write(self, text):
        for ch in text:
            self._char(ord(ch))


def find_axi_iic(ol):
    """Return an MMIO onto the first AXI IIC core in the overlay, by type."""
    for name, info in ol.ip_dict.items():
        if "axi_iic" in info.get("type", ""):
            print(f"Using AXI IIC: {name}")
            return MMIO(info["phys_addr"], info["addr_range"])
    raise RuntimeError(f"No AXI IIC IP in overlay. Available: {list(ol.ip_dict)}")
