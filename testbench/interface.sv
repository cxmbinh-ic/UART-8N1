`ifndef UART_INTERFACE_SV
`define UART_INTERFACE_SV
interface uart_interface #(
    parameter BAUD_RATE  = 115200, // UART baud-rate setting.
    parameter CLK_FREQ   = 50000000, // System clock frequency in Hz.
    parameter OVERSAMPLE = 16,     // Baud ticks per serial bit.
    parameter DATA_WIDTH = 8,      // Data bits per UART byte.
    parameter FIFO_DEPTH = 8,      // Number of entries in each FIFO.
    parameter BAUD_DIV   = CLK_FREQ / (BAUD_RATE * OVERSAMPLE) // Integer baud divider.
)(
    input logic clk // Shared system clock.
);
    logic rst_n; // Shared active-low reset.

    // UART control and serial signals.
    logic tx_valid; // Request transmission of the next TX FIFO byte.
    logic tx;       // Serial TX output, connected to RX by the testbench.
    logic tx_ready; // TX is idle; this signal also drives TX FIFO rd_en.
    logic tx_busy;  // TX is currently transmitting a frame.
    logic [DATA_WIDTH-1:0] rx_data_out; // Raw received byte, BEFORE the RX FIFO.
    logic rx_valid; // Marks rx_data_out as valid for this clock.
    logic rx_error; // Reports a UART receive error.

    // TX FIFO write interface and status.
    logic tx_fifo_cs;                 // Enable TX FIFO access.
    logic tx_fifo_wr_en;              // Request a write at the next rising edge.
    logic [DATA_WIDTH-1:0] tx_data_in; // Byte to be written into the TX FIFO.
    logic tx_fifo_empty;              // TX FIFO contains no queued bytes.
    logic tx_fifo_full;               // TX FIFO cannot accept another write.

    // RX FIFO read interface and status.
    logic rx_fifo_cs;                       // Enable RX FIFO access.
    logic rx_fifo_rd_en;                    // Request a read at the next rising edge.
    logic [DATA_WIDTH-1:0] rx_fifo_data_out; // Registered FIFO output; not compared in TC1.
    logic rx_fifo_empty;                    // RX FIFO contains no queued bytes.
    logic rx_fifo_full;                     // RX FIFO cannot accept another byte.

    // Drive at falling edges so inputs settle before the DUT's rising edges.
    clocking drv_cb @(negedge clk);
        default input #1step output #0; // Sample just before this edge; drive after it.
        output rst_n, tx_valid, tx_fifo_cs, tx_fifo_wr_en, tx_data_in;
        output rx_fifo_cs, rx_fifo_rd_en;
        input tx_ready, tx_busy, tx_fifo_empty, tx_fifo_full;
        input rx_fifo_empty, rx_fifo_full;
    endclocking

    // Sample the same pre-edge values used by the DUT to accept each transaction.
    clocking mon_cb @(posedge clk);
        default input #1step; // Avoid races with the DUT's nonblocking assignments.
        input rst_n, tx_valid, tx, tx_ready, tx_busy;
        input tx_fifo_cs, tx_fifo_wr_en, tx_data_in;
        input tx_fifo_empty, tx_fifo_full;
        input rx_data_out, rx_valid, rx_error;
        input rx_fifo_cs, rx_fifo_rd_en, rx_fifo_data_out;
        input rx_fifo_empty, rx_fifo_full;
    endclocking
endinterface
`endif
