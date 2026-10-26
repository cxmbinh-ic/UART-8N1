`ifndef UART_SCOREBOARD_SV
`define UART_SCOREBOARD_SV
class scoreboard;
    mailbox #(transaction) mbx_data_in;  // Accepted TX FIFO writes from the input monitor.
    mailbox #(transaction) mbx_data_out; // Valid UART RX bytes from the output monitor.

    // Queue models preserve the observation order; comparison happens at test end.
    logic [7:0] data_in_fifo[$];  // Expected bytes, observed at TX FIFO input.
    logic [7:0] data_out_fifo[$]; // Actual bytes, observed at raw UART RX output.
    int input_count = 0;         // Total input samples collected.
    int output_count = 0;        // Total output samples collected.
    int pass = 0;                // Number of matching byte pairs.
    int error = 0;               // Number of mismatching byte pairs.
    int total = 0;               // Number of byte pairs compared.

    function new(mailbox #(transaction) mbx_data_in,
                 mailbox #(transaction) mbx_data_out);
        this.mbx_data_in = mbx_data_in;   // Connect the input observation stream.
        this.mbx_data_out = mbx_data_out; // Connect the output observation stream.
    endfunction

    task collect_data_in();
        transaction tr;
        forever begin
            mbx_data_in.get(tr);             // Wait for the next accepted input byte.
            data_in_fifo.push_back(tr.data); // Append it to the expected FIFO model.
            input_count++;
        end
    endtask

    task collect_data_out();
        transaction tr;
        forever begin
            mbx_data_out.get(tr);             // Wait for the next received byte.
            data_out_fifo.push_back(tr.data); // Append it to the observed-output queue.
            output_count++;
        end
    endtask

    task run();
        fork
            collect_data_in();  // Collect input and output independently.
            collect_data_out(); // Neither stream has to wait for the other stream.
        join
    endtask

    // Compare only after traffic has completed and monitors have stopped.
    task compare(int expected_count);
        logic [7:0] expected_data, actual_data;

        // Check lengths first so missing or extra bytes cannot produce a false PASS.
        if (input_count != expected_count || output_count != expected_count ||
            data_in_fifo.size() != expected_count || data_out_fifo.size() != expected_count)
            $fatal(1, "[SCO] COUNT FAIL expected=%0d input=%0d output=%0d in_fifo=%0d out_fifo=%0d at %0t",
                   expected_count, input_count, output_count,
                   data_in_fifo.size(), data_out_fifo.size(), $time);

        for (int i = 0; i < expected_count; i++) begin
            expected_data = data_in_fifo.pop_front(); // Take the oldest expected byte.
            actual_data = data_out_fifo.pop_front();  // Take the oldest received byte.
            // Fail on unknown bits as well as ordinary value mismatches.
            if ($isunknown(expected_data) || $isunknown(actual_data) ||
                expected_data !== actual_data) begin
                error++;
                $display("[SCO] FAIL byte[%0d] expected=0x%02h actual=0x%02h at %0t",
                         i, expected_data, actual_data, $time);
            end else begin
                pass++;
                $display("[SCO] MATCH byte[%0d] data=0x%02h", i, actual_data);
            end
            total++;
        end
        if (error != 0) // A mismatch must fail the simulation, not just print a message.
            $fatal(1, "[SCO] FAIL total=%0d matched=%0d mismatched=%0d", total, pass, error);
        if (data_in_fifo.size() != 0 || data_out_fifo.size() != 0)
            $fatal(1, "[SCO] Model FIFOs did not drain");
        $display("[SCO] PASS total=%0d matched=%0d mismatched=%0d", total, pass, error);
    endtask
endclass
`endif
