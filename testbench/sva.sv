


// ---------------------------------------------------------------------
// 1) BAUD RATE GENERATOR  (BG-01..BG-04)
// ---------------------------------------------------------------------
module baud_gen_sva #(
    parameter BAUD_DIV = 27
)(
    input logic clk,
    input logic rst_n,
    input logic baud_tick_x16,
    input logic [$clog2(BAUD_DIV)-1:0] baud_counter
);

    // BG-04: async reset drives baud_counter/baud_tick_x16 to 0
    property p_bg_reset_values;
        @(posedge clk) !rst_n |-> (baud_counter == 0 && baud_tick_x16 == 0);
    endproperty
    assert property (p_bg_reset_values)
        else $error("[BG-04] baud_counter/baud_tick_x16 not 0 during reset");

    // BG-01: baud_tick_x16 is a single-cycle pulse
    property p_bg_single_cycle_pulse;
        @(posedge clk) disable iff (!rst_n)
        baud_tick_x16 |=> !baud_tick_x16;
    endproperty
    assert property (p_bg_single_cycle_pulse)
        else $error("[BG-01] baud_tick_x16 stayed high for 2+ cycles");

    // BG-02: period between two pulses is exactly BAUD_DIV clk cycles
    property p_bg_tick_period;
        @(posedge clk) disable iff (!rst_n)
        $rose(baud_tick_x16) |-> ##BAUD_DIV $rose(baud_tick_x16);
    endproperty
    assert property (p_bg_tick_period)
        else $error("[BG-02] baud_tick_x16 period != BAUD_DIV (%0d) clk cycles", BAUD_DIV);

    // BG-03: counter never exceeds BAUD_DIV-1
    property p_bg_counter_range;
        @(posedge clk) disable iff (!rst_n)
        baud_counter <= BAUD_DIV - 1;
    endproperty
    assert property (p_bg_counter_range)
        else $error("[BG-03] baud_counter exceeded BAUD_DIV-1");

endmodule

bind baud_rate_generator
    baud_gen_sva #(.BAUD_DIV(BAUD_DIV)) baud_gen_sva_i (.*);


// ---------------------------------------------------------------------
// 2) UART TX  (TX-S01..S05, TX-O01..O06)
// ---------------------------------------------------------------------
module uart_tx_sva #(
    parameter DATA_WIDTH = 8,
    parameter OVERSAMPLE = 16
)(
    input logic clk,
    input logic rst_n,
    input logic [DATA_WIDTH-1:0] data_in,
    input logic tx_valid,
    input logic baud_tick_x16,
    input logic tx_ready,
    input logic tx_busy,
    input logic tx,
    input logic [1:0] state,
    input logic [$clog2(OVERSAMPLE)-1:0] oversample_counter,
    input logic [$clog2(DATA_WIDTH)-1:0] tx_bit_counter
);

    localparam IDLE = 2'b00, START = 2'b01, DATA = 2'b10, STOP = 2'b11;

    // ---- always-on invariants (Priority 1) ----

    // TX-S06: state is always one of the 4 legal codes (2-bit state,
    // all 4 codes are legal here, so this really checks no X/Z escapes)
    property p_tx_legal_state;
        @(posedge clk) disable iff (!rst_n)
        !$isunknown(state) && state inside {IDLE, START, DATA, STOP};
    endproperty
    assert property (p_tx_legal_state)
        else $error("[TX-S06] tx state is X/Z or illegal: %0d", state);

    // TX-O05: tx_busy and tx_ready must always disagree
    property p_tx_busy_ready_complement;
        @(posedge clk) disable iff (!rst_n)
        tx_busy == !tx_ready;
    endproperty
    assert property (p_tx_busy_ready_complement)
        else $error("[TX-O05] tx_busy(%0b) != ~tx_ready(%0b)", tx_busy, tx_ready);

    // reset values
    property p_tx_reset_values;
        @(posedge clk) !rst_n |-> (state == IDLE && oversample_counter == 0 && tx_bit_counter == 0);
    endproperty
    assert property (p_tx_reset_values)
        else $error("[TX-RST] state/oversample_counter/tx_bit_counter not reset");

    // ---- per-state outputs (Priority 2) ----

    property p_tx_out_idle;
        @(posedge clk) disable iff (!rst_n)
        state == IDLE |-> (tx == 1'b1 && tx_ready == 1'b1 && tx_busy == 1'b0);
    endproperty
    assert property (p_tx_out_idle) else $error("[TX-O01] wrong IDLE outputs");

    property p_tx_out_start;
        @(posedge clk) disable iff (!rst_n)
        state == START |-> (tx == 1'b0 && tx_ready == 1'b0 && tx_busy == 1'b1);
    endproperty
    assert property (p_tx_out_start) else $error("[TX-O02] wrong START outputs");

    property p_tx_out_data;
        @(posedge clk) disable iff (!rst_n)
        state == DATA |-> (tx == data_in[tx_bit_counter] && tx_ready == 1'b0 && tx_busy == 1'b1);
    endproperty
    assert property (p_tx_out_data) else $error("[TX-O03] wrong DATA outputs");

    property p_tx_out_stop;
        @(posedge clk) disable iff (!rst_n)
        state == STOP |-> (tx == 1'b1 && tx_ready == 1'b0 && tx_busy == 1'b1);
    endproperty
    assert property (p_tx_out_stop) else $error("[TX-O04] wrong STOP outputs");

    // TX-F02: data_in must not change while DATA is being shifted out
    // (RTL reads data_in live every cycle instead of latching it — see
    // verification plan v2 open item 2)
    property p_tx_data_in_stable_during_data;
        @(posedge clk) disable iff (!rst_n)
        state == DATA |-> $stable(data_in);
    endproperty
    assert property (p_tx_data_in_stable_during_data)
        else $error("[TX-F02] data_in changed while state==DATA");

    // ---- state transitions (Priority 3) ----

    property p_tx_idle_to_start;
        @(posedge clk) disable iff (!rst_n)
        (state == IDLE && tx_valid) |=> state == START;
    endproperty
    assert property (p_tx_idle_to_start) else $error("[TX-S01] IDLE->START failed");

    property p_tx_start_to_data;
        @(posedge clk) disable iff (!rst_n)
        (state == START && oversample_counter == OVERSAMPLE-1 && baud_tick_x16) |=> state == DATA;
    endproperty
    assert property (p_tx_start_to_data) else $error("[TX-S02] START->DATA failed");

    property p_tx_data_bit_increment;
        @(posedge clk) disable iff (!rst_n)
        (state == DATA && oversample_counter == OVERSAMPLE-1 && baud_tick_x16
         && tx_bit_counter != DATA_WIDTH-1)
        |=> (state == DATA && tx_bit_counter == ($past(tx_bit_counter) + 1'b1));
    endproperty
    assert property (p_tx_data_bit_increment) else $error("[TX-S03] tx_bit_counter did not increment by 1");

    property p_tx_data_to_stop;
        @(posedge clk) disable iff (!rst_n)
        (state == DATA && oversample_counter == OVERSAMPLE-1 && baud_tick_x16
         && tx_bit_counter == DATA_WIDTH-1)
        |=> state == STOP;
    endproperty
    assert property (p_tx_data_to_stop) else $error("[TX-S04] DATA->STOP failed");

    property p_tx_stop_to_idle;
        @(posedge clk) disable iff (!rst_n)
        (state == STOP && oversample_counter == OVERSAMPLE-1 && baud_tick_x16) |=> state == IDLE;
    endproperty
    assert property (p_tx_stop_to_idle) else $error("[TX-S05] STOP->IDLE failed");

endmodule

bind uart_tx
    uart_tx_sva #(.DATA_WIDTH(DATA_WIDTH), .OVERSAMPLE(OVERSAMPLE)) uart_tx_sva_i (.*);


// ---------------------------------------------------------------------
// 3) UART RX  (RX-S01..S08, RX-O01..O06)
// ---------------------------------------------------------------------
module uart_rx_sva #(
    parameter DATA_WIDTH = 8,
    parameter OVERSAMPLE = 16
)(
    input logic clk,
    input logic rst_n,
    input logic rx,
    input logic baud_tick_x16,
    input logic [DATA_WIDTH-1:0] rx_data_out,
    input logic rx_valid,
    input logic rx_error,
    input logic [2:0] state,
    input logic [$clog2(OVERSAMPLE)-1:0] oversample_counter,
    input logic [$clog2(DATA_WIDTH)-1:0] rx_bit_counter,
    input logic rx_sync1,
    input logic [DATA_WIDTH-1:0] rx_shift_reg
);

    localparam IDLE = 3'b000, START = 3'b001, DATA = 3'b010, STOP = 3'b011, ERROR = 3'b100;

    // ---- always-on invariants (Priority 1) ----

    property p_rx_legal_state;
        @(posedge clk) disable iff (!rst_n)
        !$isunknown(state) && state inside {IDLE, START, DATA, STOP, ERROR};
    endproperty
    assert property (p_rx_legal_state)
        else $error("[RX-S*] rx state is X/Z or illegal: %0d", state);

    property p_rx_valid_pulse;
        @(posedge clk) disable iff (!rst_n)
        rx_valid |=> !rx_valid;
    endproperty
    assert property (p_rx_valid_pulse) else $error("[RX-O03] rx_valid stayed high for 2+ cycles");

    property p_rx_error_pulse;
        @(posedge clk) disable iff (!rst_n)
        rx_error |=> !rx_error;
    endproperty
    assert property (p_rx_error_pulse) else $error("[RX-O04] rx_error stayed high for 2+ cycles");

    property p_rx_valid_error_exclusive;
        @(posedge clk) disable iff (!rst_n)
        !(rx_valid && rx_error);
    endproperty
    assert property (p_rx_valid_error_exclusive)
        else $error("[RX-O05] rx_valid and rx_error both high in the same cycle");

    // RX-O06: rx_data_out is 0 in every cycle except when rx_valid==1
    property p_rx_data_out_zero_when_not_valid;
        @(posedge clk) disable iff (!rst_n)
        !rx_valid |-> rx_data_out == '0;
    endproperty
    assert property (p_rx_data_out_zero_when_not_valid)
        else $error("[RX-O06] rx_data_out non-zero while rx_valid==0");

    property p_rx_reset_values;
        @(posedge clk) !rst_n |-> (state == IDLE && oversample_counter == 0 && rx_bit_counter == 0);
    endproperty
    assert property (p_rx_reset_values)
        else $error("[RX-RST] state/oversample_counter/rx_bit_counter not reset");

    // ---- per-state outputs (Priority 2) ----

    property p_rx_out_valid_frame;
        @(posedge clk) disable iff (!rst_n)
        (state == STOP && oversample_counter == OVERSAMPLE/2-1 && baud_tick_x16 && rx_sync1)
        |-> (rx_valid && !rx_error && rx_data_out == rx_shift_reg);
    endproperty
    assert property (p_rx_out_valid_frame) else $error("[RX-O01] good frame did not produce rx_valid+data");

    property p_rx_out_error_frame;
        @(posedge clk) disable iff (!rst_n)
        (state == ERROR && !rx_sync1) |-> rx_error;
    endproperty
    assert property (p_rx_out_error_frame) else $error("[RX-O02] ERROR state did not assert rx_error");

    // ---- state transitions (Priority 3) ----

    property p_rx_idle_to_start;
        @(posedge clk) disable iff (!rst_n)
        (state == IDLE && !rx_sync1) |=> state == START;
    endproperty
    assert property (p_rx_idle_to_start) else $error("[RX-S01] IDLE->START failed");

    property p_rx_start_to_data;
        @(posedge clk) disable iff (!rst_n)
        (state == START && oversample_counter == OVERSAMPLE-1 && baud_tick_x16 && !rx_sync1)
        |=> state == DATA;
    endproperty
    assert property (p_rx_start_to_data) else $error("[RX-S02] START->DATA failed");

    property p_rx_start_to_idle_glitch;
        @(posedge clk) disable iff (!rst_n)
        (state == START && oversample_counter == OVERSAMPLE/2-1 && baud_tick_x16 && rx_sync1)
        |=> state == IDLE;
    endproperty
    assert property (p_rx_start_to_idle_glitch) else $error("[RX-S03] START->IDLE (glitch reject) failed");

    property p_rx_data_bit_increment;
        @(posedge clk) disable iff (!rst_n)
        (state == DATA && oversample_counter == OVERSAMPLE-1 && baud_tick_x16
         && rx_bit_counter != DATA_WIDTH-1)
        |=> (state == DATA && rx_bit_counter == ($past(rx_bit_counter) + 1'b1));
    endproperty
    assert property (p_rx_data_bit_increment)
        else $error("[RX-S04] rx_bit_counter did not increment by 1 (check next_rx_bit_counter self-reference bug)");

    property p_rx_data_to_stop;
        @(posedge clk) disable iff (!rst_n)
        (state == DATA && oversample_counter == OVERSAMPLE-1 && baud_tick_x16
         && rx_bit_counter == DATA_WIDTH-1)
        |=> state == STOP;
    endproperty
    assert property (p_rx_data_to_stop) else $error("[RX-S05] DATA->STOP failed");

    property p_rx_stop_to_idle;
        @(posedge clk) disable iff (!rst_n)
        (state == STOP && oversample_counter == OVERSAMPLE-1 && baud_tick_x16 && rx_sync1)
        |=> state == IDLE;
    endproperty
    assert property (p_rx_stop_to_idle) else $error("[RX-S06] STOP->IDLE failed");

    // ---- Priority 4: written now, only fire once the driver can force
    // rx low during the stop bit (verification plan v2, section 3, SYS-04/05) ----

    property p_rx_stop_to_error;
        @(posedge clk) disable iff (!rst_n)
        (state == STOP && oversample_counter == OVERSAMPLE/2-1 && baud_tick_x16 && !rx_sync1)
        |=> state == ERROR;
    endproperty
    assert property (p_rx_stop_to_error) else $error("[RX-S07] STOP->ERROR failed");

    property p_rx_error_to_idle;
        @(posedge clk) disable iff (!rst_n)
        (state == ERROR && rx_sync1) |=> state == IDLE;
    endproperty
    assert property (p_rx_error_to_idle) else $error("[RX-S08] ERROR->IDLE failed");

    property p_rx_error_holds;
        @(posedge clk) disable iff (!rst_n)
        (state == ERROR && !rx_sync1) |=> state == ERROR;
    endproperty
    assert property (p_rx_error_holds) else $error("[RX-S08b] ERROR state exited without rx_sync1==1");

endmodule

bind uart_rx
    uart_rx_sva #(.DATA_WIDTH(DATA_WIDTH), .OVERSAMPLE(OVERSAMPLE)) uart_rx_sva_i (.*);