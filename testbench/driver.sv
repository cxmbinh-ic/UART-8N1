class driver;
  
  parameter BAUD_RATE = 115200;
  parameter CLK_FREQ = 50000000;
  parameter OVERSAMPLE = 16;
  parameter DATA_WIDTH = 8;
  parameter BAUD_DIV = CLK_FREQ / (BAUD_RATE*OVERSAMPLE); 
  
  int i;

  
  transaction tr;
  mailbox #(transaction) mbx;
  virtual uart_interface vif;
  
  
  //event next;
  
  //contructor
  function new (mailbox #(transaction) mbx );
    this.mbx = mbx;
  endfunction
  
  
  
  //task reset
  task reset();
    $display("RESET THE DUT");
    vif.rst_n       <= 0;
    vif.tx_valid    <= 0;
    vif.tx_data_in  <= 0;
    
    repeat(5) @(posedge vif.clk);
    
    vif.rst_n       <= 1;
    vif.tx_valid    <= 1;
    $display("RELEASE THE RESET");
  endtask
  // just for tx
  task run();
    forever begin    
      //@(vif.drv_cb);
      while(!vif.tx_ready) begin
        @(posedge vif.clk);
        i ++;
        if(i > 30) $finish;
      end
	  mbx.get(tr);   
      vif.drv_cb.tx_valid    <= 1;//-> START
      @(vif.drv_cb);
      vif.drv_cb.tx_data_in  <= tr.tx_data_in; 
      //$display("[DRV] tr.tx_data_in = %0d", tr.tx_data_in);
      @(vif.drv_cb);
      vif.drv_cb.tx_valid    <= 0;     
      @(vif.drv_cb);
      wait(vif.tx_ready == 1);
      //$display("[DRV] finish drive mbx.num() = %0d ", mbx);
    end
    //$display("[DRV] finish drive");
  endtask

endclass