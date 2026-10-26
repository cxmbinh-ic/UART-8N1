`timescale 1ns/1ps // Use nanosecond delays with picosecond precision.
// Include the interface first, then classes in dependency order.
`include "interface.sv"
`include "transaction.sv"
`include "generator.sv"
`include "driver.sv"
`include "monitor.sv"
`include "scoreboard.sv"
`include "environment.sv"

module tb_uart_top;
    localparam DATA_WIDTH = 8;      // Eight data bits in each UART frame.
    localparam FIFO_DEPTH = 8;      // Each FIFO stores up to eight bytes.
    localparam OVERSAMPLE = 16;     // Sixteen baud ticks per serial bit.
    localparam CLK_PERIOD_NS = 20;  // 50 MHz system clock.

    logic clk = 0; // Start with a known clock level.
    always #(CLK_PERIOD_NS / 2) clk = ~clk; // Toggle every half clock period.

    uart_interface uif(.clk(clk)); // Shared connection for driver, monitor, and DUT.
    uart_top #(
        .DATA_WIDTH(DATA_WIDTH),
        .OVERSAMPLE(OVERSAMPLE),
        .FIFO_DEPTH(FIFO_DEPTH)
    ) dut (
        .clk(uif.clk),
        .rst_n(uif.rst_n),
        // UART TX / RX: serial loopback.
        .tx_valid(uif.tx_valid),
        .tx(uif.tx),
        .tx_ready(uif.tx_ready),
        .tx_busy(uif.tx_busy),
        .rx(uif.tx), // Feed transmitted serial bits back to the receiver.
        .rx_data_out(uif.rx_data_out), // Testcase 1 compares data at this point.
        .rx_valid(uif.rx_valid), // Qualify each received byte for the monitor.
        .rx_error(uif.rx_error),
        // TX FIFO.
        .tx_fifo_cs(uif.tx_fifo_cs),
        .tx_fifo_wr_en(uif.tx_fifo_wr_en),
        .tx_data_in(uif.tx_data_in),
        .tx_fifo_empty(uif.tx_fifo_empty),
        .tx_fifo_full(uif.tx_fifo_full),
        // RX FIFO.
        .rx_fifo_cs(uif.rx_fifo_cs),
        .rx_fifo_rd_en(uif.rx_fifo_rd_en),
        .rx_fifo_data_out(uif.rx_fifo_data_out),
        .rx_fifo_empty(uif.rx_fifo_empty),
        .rx_fifo_full(uif.rx_fifo_full)
    );

    environment env;          // Own all testbench components and their mailboxes.
    int seed = 1;             // Default reproducible random seed.
    int initial_seed;         // Preserve the seed for logging before $urandom updates it.
    int unsigned random_init; // Store the first random return value while seeding.
    initial begin
        $timeformat(-9, 0, " ns", 12); // Print readable timestamps in nanoseconds.
        if ($value$plusargs("SEED=%d", seed)) begin end // Accept an optional +SEED value.
        initial_seed = seed;
        random_init = $urandom(seed); // Seed this process and its child test threads.
        $display("[TB] SEED=%0d", initial_seed);
        env = new(uif);       // Construct and connect the testbench components.
        env.run_testcase1();  // Testcase 2 is reserved for a later specification.
    end

    // Generate a waveform only when +DUMP_VCD is requested.
    initial begin
        if ($test$plusargs("DUMP_VCD")) begin
            $dumpfile("tb_uart_fifo.vcd");
            $dumpvars(0, tb_uart_top);
        end
    end
endmodule
