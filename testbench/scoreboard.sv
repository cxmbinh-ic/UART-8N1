class scoreboard;
  
  parameter BAUD_RATE = 115200;
  parameter CLK_FREQ = 50000000;
  parameter OVERSAMPLE = 16;
  parameter DATA_WIDTH = 8;
  parameter BAUD_DIV = CLK_FREQ / (BAUD_RATE*OVERSAMPLE); 

  
  int pass  = 0;
  int error = 0;
  int total = 0;
  
  transaction tr;
  mailbox #(transaction) mbx;
  virtual uart_interface vif;
  
  //contructor
  function new (mailbox #(transaction) mbx );
    this.mbx = mbx;
  endfunction
  
  
  //golden model
  logic [DATA_WIDTH-1:0] expected_queue[$];
  
  
  task run();
    forever begin
      logic [DATA_WIDTH-1:0] expected_data;
      mbx.get(tr);
      wait(tr.tx_ready == 1);
      expected_queue.push_back(tr.tx_data_in);
      wait(tr.rx_valid == 1);
      expected_data = expected_queue.pop_front();
      //check var
      if(expected_data == tr.rx_data_out) begin
        $display("[SCO] PASS data out : %0d", tr.rx_data_out);
        pass++;
      end
      else begin
        $display("[SCO] FAIL data out : %0d", tr.rx_data_out);
        error++;
      end
      total ++;
    end
    
  endtask
  
endclass