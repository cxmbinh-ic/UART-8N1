`ifndef UART_TRANSACTION_SV
`define UART_TRANSACTION_SV
class transaction;
    rand logic [7:0] data; // Random byte; logic also preserves X/Z in monitored data.
    time sample_time;     // Time at which the monitor observed this byte.
endclass
`endif
