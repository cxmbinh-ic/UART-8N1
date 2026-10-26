`ifndef UART_DRIVER_SV
`define UART_DRIVER_SV
class driver;
    mailbox #(transaction) mbx;       // Bytes waiting to be written into the TX FIFO.
    virtual uart_interface vif;      // Drive DUT inputs at falling clock edges.
    int byte_count;                   // Assigned from gen.count by the environment before traffic starts.
    int access_cycles;               // Clock cycles between two random enable decisions.
    int sent_count = 0;               // Successful writes; rejected attempts do not count.
    int write_trials = 0;             // Number of random TX write decisions.
    int write_ones = 0;               // Number of decisions that selected wr_en = 1.
    int read_trials = 0;              // Number of random RX read decisions.
    int read_ones = 0;                // Number of decisions that selected rd_en = 1.
    bit done = 0;                     // Set after all byte_count bytes have been accepted.

    function new(mailbox #(transaction) mbx, int access_cycles);
        this.mbx = mbx;                       // Connect the generator mailbox.
        this.access_cycles = access_cycles;   // Set the FIFO access interval.
    endfunction

    // Initialize every driven signal and hold reset for five system clocks.
    task reset();
        @(vif.drv_cb);
        vif.drv_cb.rst_n         <= 0; // Assert the shared active-low reset.
        vif.drv_cb.tx_valid      <= 0; // Do not launch a UART frame during reset.
        vif.drv_cb.tx_data_in    <= 0; // Give the data bus a known initial value.
        vif.drv_cb.tx_fifo_cs    <= 1; // Enable the TX FIFO.
        vif.drv_cb.tx_fifo_wr_en <= 0; // Start with writes disabled.
        vif.drv_cb.rx_fifo_cs    <= 1; // Enable the RX FIFO.
        vif.drv_cb.rx_fifo_rd_en <= 0; // Start with reads disabled.
        repeat (5) @(vif.drv_cb);
        if (vif.drv_cb.tx_fifo_empty !== 1'b1 ||
            vif.drv_cb.rx_fifo_empty !== 1'b1 ||
            vif.drv_cb.tx_fifo_full !== 1'b0 ||
            vif.drv_cb.rx_fifo_full !== 1'b0)
            $fatal(1, "[DRV] Incorrect FIFO reset flags at %0t", $time);
        vif.drv_cb.rst_n <= 1;         // Release reset before the next rising edge.
        @(vif.drv_cb);
    endtask

    // Try one write per access interval. A successful request lasts one clock.
    task write_tx_fifo();
        transaction tr;
        bit write_enable;
        bit accepted;

        @(vif.drv_cb); // Start on a driver clocking event after all threads are running.
        repeat (byte_count) begin
            mbx.get(tr); // Take the next byte; keep it until the FIFO accepts it.
            accepted = 0;
            while (!accepted) begin
                write_enable = $urandom_range(0, 1); // Independent 50% chance of 0 or 1.
                write_trials++;
                write_ones += write_enable;
                vif.drv_cb.tx_data_in <= tr.data;          // Present the pending byte.
                vif.drv_cb.tx_fifo_wr_en <= write_enable;  // Apply this interval's decision.
                // FULL sampled at this falling edge also applies at the next rising edge.
                accepted = write_enable && !vif.drv_cb.tx_fifo_full;
                @(vif.drv_cb);                             // Allow one rising edge to occur.
                vif.drv_cb.tx_fifo_wr_en <= 0;             // End the one-clock write pulse.
                if (accepted) sent_count++;               // Count only a successful write.
                repeat (access_cycles - 1) @(vif.drv_cb); // Wait for the next access slot.
            end
        end
        done = 1; // No more writes; UART TX may still have queued bytes to transmit.
    endtask

    // Keep UART TX fed whenever the TX FIFO contains a byte.
    task control_tx();
        forever begin
            @(vif.drv_cb);
            // TX accepts this request only while idle. Its tx_ready also pops the FIFO.
            vif.drv_cb.tx_valid <= !vif.drv_cb.tx_fifo_empty;
        end
    endtask

    // Make independent random read decisions at the same rate as write decisions.
    task read_rx_fifo();
        bit read_enable;
        @(vif.drv_cb);
        forever begin
            read_enable = $urandom_range(0, 1); // Independent 50% chance of 0 or 1.
            read_trials++;
            read_ones += read_enable;
            vif.drv_cb.rx_fifo_rd_en <= read_enable; // Empty FIFO reads are ignored by RTL.
            @(vif.drv_cb);                           // Allow one rising edge to perform a read.
            vif.drv_cb.rx_fifo_rd_en <= 0;           // End the one-clock read pulse.
            repeat (access_cycles - 1) @(vif.drv_cb); // Keep data buffered between read slots.
        end
    endtask

    task run();
        fork
            write_tx_fifo(); // Produce exactly byte_count accepted input bytes.
            control_tx();    // Let UART TX transmit queued bytes continuously.
            read_rx_fifo();  // Randomly drain the RX FIFO independently.
        join
    endtask
endclass
`endif
