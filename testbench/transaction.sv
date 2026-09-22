class transaction #(
    parameter DATA_WIDTH = 8
);

    // Randomized stimulus
    rand bit [DATA_WIDTH-1:0] tx_data_in;

    // Non-random
    bit                    rx;
    bit                    tx_valid;
    bit                    tx;
    bit                    tx_ready;
    bit                    tx_busy;
    bit [DATA_WIDTH-1:0]   rx_data_out;
    bit                    rx_valid;
    bit                    rx_error;

    // Constraint: tx_data_in restricted between 1 and 50
    constraint tx_data_ctrl {
        tx_data_in inside {[1:50]};
    }

endclass