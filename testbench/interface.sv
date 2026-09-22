interface uart_interface #(
    parameter BAUD_RATE  = 115200,
    parameter CLK_FREQ   = 50000000,
    parameter OVERSAMPLE = 16,
    parameter DATA_WIDTH = 8,
    parameter BAUD_DIV   = CLK_FREQ / (BAUD_RATE * OVERSAMPLE)
)(
    input logic clk
);

    // -------------------------------------------------------------
    // Signal Declarations 
    // -------------------------------------------------------------
    logic                  rst_n;
    //logic                  rx;
    logic                  tx_valid;
    logic [DATA_WIDTH-1:0] tx_data_in;
    logic                  tx;
    logic                  tx_ready;
    logic                  tx_busy;
    logic [DATA_WIDTH-1:0] rx_data_out;
    logic                  rx_valid;
    logic                  rx_error;

    // Driver clocking block 
    clocking drv_cb @(posedge clk);
        default input #1step output #0;
        output rst_n;
        output tx_valid;
        output tx_data_in;
    endclocking

    // Monitor clocking block 
    clocking mon_cb @(posedge clk);
        default input #1step;
        input  tx_data_in;
        input  tx;
        input  tx_ready;
        input  tx_busy;
        input  rx_data_out;
        input  rx_valid;
        input  rx_error;
    endclocking


endinterface