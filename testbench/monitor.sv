class monitor;
  
  parameter BAUD_RATE = 115200;
  parameter CLK_FREQ = 50000000;
  parameter OVERSAMPLE = 16;
  parameter DATA_WIDTH = 8;
  parameter BAUD_DIV = CLK_FREQ / (BAUD_RATE*OVERSAMPLE); 

  
  transaction tr;
  mailbox #(transaction) mbx;
  virtual uart_interface vif;
  
  int i = 0;
  //event next;
  
  //contructor
  function new (mailbox #(transaction) mbx );
    this.mbx = mbx;
    tr = new();
  endfunction
  
  task run();
    
    forever begin
      @(vif.drv_cb);
      
      wait(vif.mon_cb.tx_ready == 1);
      
      tr.tx_ready     = vif.mon_cb.tx_ready;
      @(vif.drv_cb);
      tr.tx_data_in   = vif.mon_cb.tx_data_in;
      //$display("[MON] tr.tx_data_in = %0d", tr.tx_data_in);
      
      wait(vif.mon_cb.rx_valid == 1);
      tr.rx_valid     = vif.mon_cb.rx_valid;
      
      tr.rx_data_out  = vif.mon_cb.rx_data_out;
      mbx.put(tr);
      $display("[MON]: time = %t tx_data_in = %0d  rx_data_out = %0d",$time ,tr.tx_data_in,tr.rx_data_out);  
    end
  endtask
endclass