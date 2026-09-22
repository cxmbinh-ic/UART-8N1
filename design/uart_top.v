module uart_top #(
    parameter DATA_WIDTH = 8,
    parameter OVERSAMPLE = 16
)(
    input clk,rst_n,
    input rx,
    input tx_valid,
    input [DATA_WIDTH-1:0] tx_data_in,
    output tx,
    output tx_ready,
    output tx_busy,
    output [DATA_WIDTH-1:0] rx_data_out,
    output rx_valid,
    output rx_error
);

//BAUD RATE GENERATOR
wire baud_tick_x16;
baud_rate_generator #(
    .BAUD_RATE(115200),
    .CLK_FREQ(50000000),
    .OVERSAMPLE(OVERSAMPLE)
) baud_gen (
    .clk(clk),
    .rst_n(rst_n),
    .baud_tick_x16(baud_tick_x16)
);

// UART TX
uart_tx #(
    .DATA_WIDTH(DATA_WIDTH),
    .OVERSAMPLE(OVERSAMPLE)
) uart_tx_inst (
    .clk(clk),
    .rst_n(rst_n),
    .data_in(tx_data_in),
    .tx_valid(tx_valid),
    .baud_tick_x16(baud_tick_x16),
    .tx_ready(tx_ready),
    .tx_busy(tx_busy),
    .tx(tx)
);

// UART RX
uart_rx #(
    .DATA_WIDTH(DATA_WIDTH),
    .OVERSAMPLE(OVERSAMPLE)
) uart_rx_inst (
    .clk(clk),
    .rst_n(rst_n),
    .rx(rx),
    .baud_tick_x16(baud_tick_x16),
    .rx_data_out(rx_data_out),
    .rx_valid(rx_valid),
    .rx_error(rx_error)
);

endmodule
