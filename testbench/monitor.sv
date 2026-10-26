`ifndef UART_MONITOR_SV
`define UART_MONITOR_SV
class monitor;
    mailbox #(transaction) mbx_data_in;  // Accepted TX FIFO writes go to this mailbox.
    mailbox #(transaction) mbx_data_out; // Valid UART RX bytes go to this mailbox.
    virtual uart_interface vif;         // Read DUT signals through the monitor clocking block.
    int input_count = 0;                // Number of bytes accepted by the TX FIFO.
    int output_count = 0;               // Number of bytes produced by UART RX.

    function new(mailbox #(transaction) mbx_data_in,
                 mailbox #(transaction) mbx_data_out);
        this.mbx_data_in = mbx_data_in;   // Connect the input monitor to the scoreboard.
        this.mbx_data_out = mbx_data_out; // Connect the output monitor to the scoreboard.
    endfunction

    // Record a byte only when the TX FIFO accepts the write at this rising edge.
    task monitor_data_in();
        transaction tr;
        forever begin
            @(vif.mon_cb); // Sample the values used by the DUT at the rising edge.
            if (vif.mon_cb.rst_n === 1'b1 &&
                vif.mon_cb.tx_fifo_cs === 1'b1 &&
                vif.mon_cb.tx_fifo_wr_en === 1'b1 &&
                vif.mon_cb.tx_fifo_full === 1'b0) begin
                tr = new();                             // Give each sample its own object.
                tr.data = vif.mon_cb.tx_data_in;         // Capture the accepted input byte.
                tr.sample_time = $time;                  // Save the acceptance time.
                mbx_data_in.put(tr);                     // Send the byte to the input queue.
                input_count++;                          // Count accepted writes, not attempts.
                $display("[MON IN ] #%0d data=0x%02h at %0t", input_count, tr.data, $time);
            end
        end
    endtask

    // Testcase 1 checks UART RX data BEFORE it enters the RX FIFO.
    task monitor_data_out();
        transaction tr;
        forever begin
            @(vif.mon_cb); // rx_valid and rx_data_out are sampled on the same edge.
            if (vif.mon_cb.rst_n === 1'b1 && vif.mon_cb.rx_valid === 1'b1) begin
                tr = new();                             // Never reuse a queued object.
                tr.data = vif.mon_cb.rx_data_out;        // Capture the raw UART RX byte.
                tr.sample_time = $time;                  // Save the receive time.
                mbx_data_out.put(tr);                    // Send the byte to the output queue.
                output_count++;
                $display("[MON OUT] #%0d data=0x%02h at %0t", output_count, tr.data, $time);
            end
        end
    endtask

    // Report UART errors independently of the two data-monitor threads.
    task monitor_status();
        forever begin
            @(vif.mon_cb);
            if (vif.mon_cb.rst_n === 1'b1) begin
                if ($isunknown({vif.mon_cb.tx_ready, vif.mon_cb.tx_busy,
                                vif.mon_cb.tx_fifo_empty, vif.mon_cb.tx_fifo_full,
                                vif.mon_cb.rx_valid, vif.mon_cb.rx_error}))
                    $fatal(1, "[MON] Unknown UART/TX FIFO status at %0t", $time);
                if (vif.mon_cb.rx_error)
                    $fatal(1, "[MON] UART RX error at %0t", $time);
                // RX FIFO storage/overflow is outside testcase 1's comparison point.
            end
        end
    endtask

    task run();
        fork
            monitor_data_in();  // Observe accepted input bytes continuously.
            monitor_data_out(); // Observe received bytes independently of input timing.
            monitor_status();   // Watch for protocol/status errors in parallel.
        join
    endtask
endclass
`endif
