class generator;

  transaction tr;
  mailbox #(transaction) mbx;
  int count;

  // Constructor
  function new(mailbox #(transaction) mbx);
    this.mbx = mbx;
  endfunction

  // Stimulus generation task
  task run();
    for (int i = 0; i < count; i++) begin
      tr = new();
      assert(tr.randomize()) else $error("[GEN] Randomization failed!");
      mbx.put(tr);
      $display("[GEN]: tx_data_in : %0d", tr.tx_data_in);
    end
  endtask

endclass