module uart_top #(
    parameter DATA_WIDTH = 8,
    parameter OVERSAMPLE = 16,
    parameter FIFO_DEPTH = 8
)(
    // ==================== CLOCK / RESET CHUNG ====================
    input                       clk,              // Clock cho UART TX/RX va ca hai FIFO
    input                       rst_n,            // Reset active-low dung chung

    // ========================== UART TX ==========================
    input                       tx_valid,         // Yeu cau UART TX phat du lieu tu TX FIFO
    output                      tx,               // Duong serial TX
    output                      tx_ready,         // TX san sang; noi voi rd_en cua TX FIFO
    output                      tx_busy,          // TX dang phat mot frame

    // ========================== UART RX ==========================
    input                       rx,               // Duong serial RX
    output [DATA_WIDTH-1:0]      rx_data_out,      // Du lieu tu UART RX; noi vao data_in cua RX FIFO
    output                      rx_valid,         // Du lieu RX hop le; noi voi wr_en cua RX FIFO
    output                      rx_error,         // Bao loi nhan UART

    // ========================== TX FIFO ==========================
    input                       tx_fifo_cs,       // Cho phep TX FIFO hoat dong
    input                       tx_fifo_wr_en,    // Yeu cau ghi du lieu vao TX FIFO
    input  [DATA_WIDTH-1:0]      tx_data_in,       // Du lieu ghi vao TX FIFO tu ben ngoai
    output                      tx_fifo_empty,    // TX FIFO rong
    output                      tx_fifo_full,     // TX FIFO day
    // TX FIFO data_out -> UART TX data_in (ket noi noi bo)

    // ========================== RX FIFO ==========================
    input                       rx_fifo_cs,       // Cho phep RX FIFO hoat dong
    input                       rx_fifo_rd_en,    // Yeu cau doc du lieu tu RX FIFO
    output [DATA_WIDTH-1:0]      rx_fifo_data_out, // Du lieu doc tu RX FIFO, cap nhat sau canh clock doc
    output                      rx_fifo_empty,    // RX FIFO rong
    output                      rx_fifo_full      // RX FIFO day
);

wire [DATA_WIDTH-1:0] tx_fifo_data_out;

// TX FIFO: external data is queued before reaching the transmitter.
// data_out is registered; tx_valid remains externally controlled.
fifo_sync #(
    .FIFO_DEPTH(FIFO_DEPTH),
    .DATA_WIDTH(DATA_WIDTH)
) tx_fifo_inst (
    .clk(clk),
    .rst_n(rst_n),
    .cs(tx_fifo_cs),
    .wr_en(tx_fifo_wr_en),
    .rd_en(tx_ready && tx_valid), // Read from TX FIFO when TX is ready and tx_valid is asserted
    .data_in(tx_data_in),
    .data_out(tx_fifo_data_out),
    .empty(tx_fifo_empty),
    .full(tx_fifo_full)
);

// RX FIFO: each rx_valid pulse writes the received data.
fifo_sync #(
    .FIFO_DEPTH(FIFO_DEPTH),
    .DATA_WIDTH(DATA_WIDTH)
) rx_fifo_inst (
    .clk(clk),
    .rst_n(rst_n),
    .cs(rx_fifo_cs),
    .wr_en(rx_valid),
    .rd_en(rx_fifo_rd_en),
    .data_in(rx_data_out),
    .data_out(rx_fifo_data_out),
    .empty(rx_fifo_empty),
    .full(rx_fifo_full)
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
    .data_in(tx_fifo_data_out),
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
