`ifndef UART_ENVIRONMENT_SV
`define UART_ENVIRONMENT_SV
class environment;
    generator gen;   // Creates random data bytes.
    driver drv;      // Drives TX FIFO writes, UART requests, and RX FIFO reads.
    monitor mon;     // Observes accepted inputs and raw UART RX outputs.
    scoreboard sco;  // Stores two queues and compares them at the end.
    virtual uart_interface vif;

    mailbox #(transaction) mbx_gen2drv;     // Generator -> driver.
    mailbox #(transaction) mbx_mon_in2sco;  // Input monitor -> scoreboard input queue.
    mailbox #(transaction) mbx_mon_out2sco; // Output monitor -> scoreboard output queue.

    // Match the DUT: integer baud divider = 27, 16 ticks/bit, 10 bits/8N1 frame.
    localparam int FRAME_CYCLES = (50000000 / (115200 * 16)) * 16 * 10; // 4320 clocks.
    localparam int ACCESS_CYCLES = FRAME_CYCLES / 2; // Two access slots per UART byte.

    function new(virtual uart_interface vif);
        this.vif = vif;
        mbx_gen2drv = new();                      // Create the stimulus mailbox.
        mbx_mon_in2sco = new();                   // Create an independent input mailbox.
        mbx_mon_out2sco = new();                  // Create an independent output mailbox.
        gen = new(mbx_gen2drv);
        drv = new(mbx_gen2drv, ACCESS_CYCLES);
        mon = new(mbx_mon_in2sco, mbx_mon_out2sco);
        sco = new(mbx_mon_in2sco, mbx_mon_out2sco);
        drv.vif = vif;                           // Give the driver access to the interface.
        mon.vif = vif;                           // Give the monitor access to the interface.
    endfunction

    // Testcase 1: use the generator's configured count and check raw UART RX data.
    task run_testcase1();
        if (gen.count <= 0)              // Reject an empty test instead of reporting a false PASS.
            $fatal(1, "[TC1] generator.count must be greater than zero");
        drv.byte_count = gen.count;      // The driver and generator use the same count.
        drv.reset();                     // Reset the UART and both FIFOs.
        gen.run();                       // Fill the stimulus mailbox before starting traffic.
        $display("[TC1] bytes=%0d access_interval=%0d clocks, wr_en/rd_en probability=50%%",
                 gen.count, ACCESS_CYCLES);

        fork
            drv.run(); // Drive all three control paths in parallel.
            mon.run(); // Observe both sides continuously.
            sco.run(); // Collect both streams without comparing early.
            begin : watchdog
                // Allow ample time for random disabled slots and FIFO backpressure.
                repeat (gen.count * FRAME_CYCLES * 10) @(vif.drv_cb);
                $fatal(1, "[TC1] TIMEOUT at %0t sent=%0d input=%0d output=%0d",
                       $time, drv.sent_count, sco.input_count, sco.output_count);
            end
        join_none

        wait (drv.done && sco.output_count >= gen.count); // Wait for all expected RX bytes.
        // Wait until the final stop bit completes and the TX FIFO has drained.
        do @(vif.drv_cb);
        while (vif.drv_cb.tx_busy !== 1'b0 || vif.drv_cb.tx_fifo_empty !== 1'b1);
        repeat (FRAME_CYCLES) @(vif.drv_cb); // Observe one extra frame time for duplicate data.

        if (drv.sent_count != gen.count || mbx_gen2drv.num() != 0 ||
            mbx_mon_in2sco.num() != 0 || mbx_mon_out2sco.num() != 0)
            $fatal(1, "[TC1] Incorrect sent count or unprocessed mailbox entries");
        if (vif.drv_cb.tx_busy !== 1'b0 || vif.drv_cb.tx_fifo_empty !== 1'b1)
            $fatal(1, "[TC1] TX did not remain idle after the last byte");

        disable fork; // Stop driver, monitor, collector, and watchdog threads.
        sco.compare(gen.count); // Check counts and compare all configured bytes in FIFO order.
        $display("[TC1] Random decisions: write ones/trials=%0d/%0d, read ones/trials=%0d/%0d",
                 drv.write_ones, drv.write_trials, drv.read_ones, drv.read_trials);
        $display("[ENV] PASS: testcase 1, %0d bytes matched at rx_data_out before RX FIFO", gen.count);
        $finish;
    endtask

    // Testcase 2 will be added after its stimulus and expected behavior are specified.
endclass
`endif
