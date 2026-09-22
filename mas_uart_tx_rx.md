# Microarchitectural Specification (MAS): UART Transmitter/Receiver (8N1)

## 1. High-Level Overview
* **Purpose:** Provide asynchronous serial communication (UART) between the FPGA and a host/peer device, transmitting and receiving 8-bit data words framed as Start-Data-Stop (8N1), for FPGA loopback validation on a Basys/Nexys board.
* **Features:**
  * System clock: 50 MHz
  * Baud rate: 115200 bps (configurable via `BAUD_DIV` parameter)
  * Oversampling: 16x — baud tick generator toggles at 16 × baud rate for mid-bit sampling on RX
  * Baud divisor: `CLK_FREQ / (16 × BAUD_RATE)` = 50,000,000 / (16 × 115,200) ≈ 27 *(assuming 50 MHz; adjust `BAUD_DIV` if the board clock differs)*
  * Frame format: 1 start bit (low), 8 data bits (LSB first), no parity, 1 stop bit (high) — fixed 8N1, not runtime-configurable
  * Independent TX and RX datapaths sharing one baud-tick generator
  * Framing-error detection on RX (missing/invalid stop bit)
* **Supported Protocols:** None (custom asynchronous serial / UART physical layer). Host-side interface is a simple valid/ready-style handshake, not a bus protocol (no APB/AXI).

## 2. Block Diagram Description
The block is composed of four sub-modules sharing a single clock and reset domain:

* **Baud Rate Generator:** A free-running counter that counts from `0` to `BAUD_DIV - 1` on every `clk` cycle and wraps, asserting a single-cycle pulse `baud_tick_x16` each time it wraps. This pulse fires at 16× the baud rate (16 ticks per bit period) and feeds both the TX Control FSM (which advances one bit every 16 ticks) and the RX Control FSM (which uses it to locate the bit-center sample point).
* **TX Datapath:** Consists of the TX Control FSM and an 8-bit parallel-in/serial-out shift register (`tx_shift_reg`) plus a bit counter (`tx_bit_cnt`, counts oversample ticks 0–15 per bit and bit index 0–7 for data bits). When the FSM loads a new byte, `tx_shift_reg` is loaded with `{1'b1 (stop), tx_data[7:0], 1'b0 (start)}` conceptually — in practice the FSM drives `tx` directly per state (`START` drives 0, `DATA` drives `tx_shift_reg[tx_bit_cnt]`, `STOP` drives 1) rather than framing the whole word in the shift register at once.
* **RX Datapath:** Consists of the RX Control FSM, a 2-flip-flop synchronizer on the async `rx` input (`rx_sync0` → `rx_sync1`), an oversample counter (`rx_os_cnt`, 0–15, reset on every state entry) used to find the sample point at count 7 (bit center), and an 8-bit serial-in/parallel-out shift register (`rx_shift_reg`) that captures one data bit per bit period at the sampled center.
* **Control/Status glue:** `tx_busy` is asserted for the duration the TX FSM is not in `IDLE`; `rx_valid` pulses for one cycle when a byte has been fully received and passed frame checking; `rx_error` pulses (or optionally latches, see assumption below) when the sampled stop bit is not `1`.

Data flow: Host asserts `tx_valid` + `tx_data` → TX Control FSM (gated by `baud_tick_x16`) → shifts bits out serially on `tx` → (physical loopback wire on the board) → `rx` pin → 2-FF synchronizer → RX Control FSM (gated by `baud_tick_x16`, sampling at oversample count 7) → `rx_shift_reg` → `rx_data` + `rx_valid` pulse to host/testbench.

## 3. Interface Signals (Pinout)
| Signal Name | Direction | Width | Description |
| :--- | :--- | :--- | :--- |
| clk | Input | 1 | System clock, 50 MHz |
| rst_n | Input | 1 | Asynchronous reset, active-low |
| tx_data | Input | [7:0] | Byte to transmit; sampled on the cycle `tx_valid && tx_ready` are both high |
| tx_valid | Input | 1 | Host asserts high to request transmission of `tx_data`; must stay high until `tx_ready` is seen high in the same cycle (single-cycle handshake) |
| tx_ready | Output | 1 | High whenever the TX FSM is in `IDLE` and able to accept a new byte; low while a frame is being shifted out |
| tx_busy | Output | 1 | High whenever TX FSM is not in `IDLE` (redundant with `~tx_ready`, provided for readability in testbenches) |
| tx | Output | 1 | Serial data output pin (idles high; drives low for the start bit) |
| rx | Input | 1 | Serial data input pin (asynchronous to `clk`; internally synchronized) |
| rx_data | Output | [7:0] | Last successfully received byte; valid on the cycle `rx_valid` is high, and held stable until the next `rx_valid` pulse |
| rx_valid | Output | 1 | Single-cycle pulse, high for one `clk` cycle when a new byte has been received and the stop bit was correctly sampled as `1` |
| rx_error | Output | 1 | Single-cycle pulse, high for one `clk` cycle when the sampled stop bit was `0` (framing error); mutually exclusive with `rx_valid` for a given frame *(assuming pulsed, not latched — see Section 6)* |

## 4. Register Map (CSR)
Not applicable. This block is a standalone datapath IP (not memory-mapped); it exposes a direct signal-level handshake interface (Section 3) rather than a CSR bus. If a later revision wraps this core with an APB/AXI-Lite register interface (e.g., for interrupt-driven use), that would be a separate MAS revision adding this section.

## 5. Functional Behavior & FSMs

### Baud Rate Generator (free-running counter, not a user-facing FSM)
* `baud_cnt` is an unsigned counter, width `$clog2(BAUD_DIV)`, incrementing every `clk` cycle.
* When `baud_cnt == BAUD_DIV - 1`: on the next clock edge, `baud_cnt` resets to `0` and `baud_tick_x16` pulses high for exactly one cycle.
* `BAUD_DIV = 27` for 50 MHz / 115200 baud / 16x oversampling *(computed as `round(50_000_000 / (16 × 115200))`; recompute if `CLK_FREQ` or `BAUD_RATE` parameters change)*.
* Runs continuously regardless of TX/RX FSM state — both FSMs count ticks of this same generator so TX and RX bit timing stay aligned to the same 16x grid.

### TX Control FSM
* **States:** `TX_IDLE`, `TX_START`, `TX_DATA`, `TX_STOP`.
* **State Transitions:**
  * `TX_IDLE` → `TX_START`: occurs when `tx_valid == 1'b1` (and therefore `tx_ready == 1'b1` that same cycle); `tx_data` is latched into `tx_shift_reg` and `tx_bit_cnt` (data-bit index) is reset to `0` on this transition.
  * `TX_START` → `TX_DATA`: occurs when the oversample tick counter reaches 16 ticks (`os_cnt == 15 && baud_tick_x16 == 1'b1`) since entering `TX_START`, i.e., one full bit period has elapsed while `tx` was held low.
  * `TX_DATA` → `TX_DATA`: occurs when one bit period elapses (`os_cnt == 15 && baud_tick_x16`) and `tx_bit_cnt < 7`; `tx_bit_cnt` increments and the next data bit (`tx_shift_reg[tx_bit_cnt+1]`) is driven onto `tx`.
  * `TX_DATA` → `TX_STOP`: occurs when one bit period elapses and `tx_bit_cnt == 7` (all 8 data bits sent).
  * `TX_STOP` → `TX_IDLE`: occurs when one bit period elapses while `tx` is held high (the stop bit).
* **Output behavior per state:** `TX_IDLE` drives `tx = 1'b1`, `tx_ready = 1'b1`; `TX_START` drives `tx = 1'b0`, `tx_ready = 1'b0`; `TX_DATA` drives `tx = tx_shift_reg[tx_bit_cnt]`, `tx_ready = 1'b0`; `TX_STOP` drives `tx = 1'b1`, `tx_ready = 1'b0`.

### RX Control FSM
* **States:** `RX_IDLE`, `RX_START`, `RX_DATA`, `RX_STOP`, `RX_ERROR`.
* **State Transitions:**
  * `RX_IDLE` → `RX_START`: occurs when the synchronized input `rx_sync1 == 1'b0` (falling edge / start-bit candidate detected). `rx_os_cnt` is reset to `0` on this transition.
  * `RX_START` → `RX_IDLE`: occurs if, at the bit-center sample point (`rx_os_cnt == 7 && baud_tick_x16`), `rx_sync1 == 1'b1` — a glitch, not a real start bit; FSM aborts back to `RX_IDLE` without asserting `rx_error` (this is a de-glitch/false-start check, not a framing violation).
  * `RX_START` → `RX_DATA`: occurs when `rx_os_cnt == 15 && baud_tick_x16` and the center sample at `rx_os_cnt == 7` confirmed `rx_sync1 == 1'b0` (valid start bit); `rx_bit_cnt` (data-bit index) resets to `0`.
  * `RX_DATA` → `RX_DATA`: occurs when `rx_os_cnt == 15 && baud_tick_x16` and `rx_bit_cnt < 7`; the bit sampled at `rx_os_cnt == 7` of the current bit period is shifted into `rx_shift_reg[rx_bit_cnt]`, then `rx_bit_cnt` increments.
  * `RX_DATA` → `RX_STOP`: occurs when `rx_os_cnt == 15 && baud_tick_x16` and `rx_bit_cnt == 7` (8th data bit just captured).
  * `RX_STOP` → `RX_IDLE`: occurs when the center sample (`rx_os_cnt == 7 && baud_tick_x16`) of the stop-bit period reads `rx_sync1 == 1'b1`; on this same transition `rx_data <= rx_shift_reg` and `rx_valid` pulses high for one cycle.
  * `RX_STOP` → `RX_ERROR`: occurs when the center sample of the stop-bit period reads `rx_sync1 == 1'b0` (expected stop bit missing); `rx_error` pulses high for one cycle on this transition.
  * `RX_ERROR` → `RX_IDLE`: occurs unconditionally on the next clock cycle (single-cycle error state; does not wait for line idle) *(assumption — alternative is to wait for `rx_sync1 == 1'b1` for a full bit period before re-arming, to avoid re-triggering mid-glitch; flag if the teacher's loopback test expects that instead)*.
* **Sampling convention:** every bit (start, data×8, stop) is sampled once, at `rx_os_cnt == 7` — the middle of its 16-tick bit period — to avoid transition-edge jitter. `rx_os_cnt` itself resets to `0` at the start of every new bit period, driven by `baud_tick_x16`.

### Timing Diagrams / Waveform Description
* **TX, byte 0x55 example:** Cycle 0: `tx_valid=1`, `tx_data=8'h55`, `tx_ready=1` → FSM latches data, moves to `TX_START` next cycle, `tx` drops to `0`. For the next 16 `baud_tick_x16` pulses (16 clk cycles at the 27-cycle-per-tick rate ⇒ 16×27 ≈ 432 clk cycles), `tx` stays `0`. FSM then enters `TX_DATA`, driving `tx_shift_reg[0]` (LSB first) for one bit period, then `[1]`...`[7]`, each held for 16 ticks. FSM then enters `TX_STOP`, driving `tx=1` for one bit period, then returns to `TX_IDLE` with `tx_ready=1` again.
* **RX, byte 0x55 example:** `rx` (looped back from `tx`) falls to `0` → `RX_IDLE`→`RX_START` same cycle. At `rx_os_cnt==7` within `RX_START`, `rx_sync1` is re-checked as `0` (confirms real start bit, not glitch). At `rx_os_cnt==15`, FSM moves to `RX_DATA`. Each of the 8 data bits is sampled once at its own `rx_os_cnt==7` and shifted into `rx_shift_reg`. After the 8th bit, FSM moves to `RX_STOP`; at that bit period's `rx_os_cnt==7`, `rx_sync1` is sampled — if `1`, `rx_data` updates and `rx_valid` pulses for exactly 1 `clk` cycle; if `0`, `rx_error` pulses instead.

## 6. Verification Considerations
* **Loopback self-check:** Primary test is `tx` physically or logically wired to `rx`; drive `tx_data`/`tx_valid` from the testbench, wait for `rx_valid`, and check `rx_data == tx_data` for a randomized sequence of bytes (all-zeros, all-ones, alternating `0x55`/`0xAA`, and fully random bytes).
* **Back-to-back transmission:** Assert `tx_valid` for a new byte on the very cycle `tx_ready` returns high (no idle gap between frames) and confirm the RX side correctly re-synchronizes to the next start bit immediately after the previous stop bit, with no missed or duplicated bytes.
* **Reset mid-frame:** Assert `rst_n` low while TX is mid-`TX_DATA` and while RX is mid-`RX_DATA`; confirm both FSMs return cleanly to `TX_IDLE`/`RX_IDLE`, `tx` returns to idle-high, and no spurious `rx_valid`/`rx_error` pulse occurs.
* **Framing error injection:** Force `rx` (or the loopback wire) low during what should be the stop-bit window (e.g., inject a stuck-low line or truncate the frame) and confirm `rx_error` pulses exactly once and `rx_valid` does not pulse for that frame.
* **Start-bit glitch rejection:** Inject a single-cycle low glitch on `rx` that does not persist to the `rx_os_cnt==7` center-sample point in `RX_START`; confirm the FSM returns to `RX_IDLE` without asserting `rx_error` or `rx_valid`.
* **Baud divisor boundary:** Since `BAUD_DIV = 27` is a rounded value (true divisor ≈ 27.13), confirm cumulative timing drift across a full 10-bit frame (start + 8 data + stop = 160 oversample ticks) stays within the receiver's sampling tolerance — i.e., the center-sample point of the 10th bit must still land inside that bit's valid window. Flag this to the teacher/grader if the board's actual clock is not exactly 50 MHz, since drift compounds with clock inaccuracy.
* **CDC on `rx`:** `rx` is asynchronous to `clk` (external pin), so the 2-FF synchronizer (`rx_sync0`→`rx_sync1`) must be verified to actually break metastability paths in synthesis (no logic between the two flops, correct `ASYNC_REG`/timing-exception constraints if the toolchain requires them for the Basys/Nexys XDC).
* **`tx_valid` held high beyond one cycle:** Since the handshake is defined as single-cycle (Section 3), verify behavior if the host holds `tx_valid` high for multiple cycles after `tx_ready` drops — the design must not re-trigger a second transmission until `tx_ready` returns high again.
