class environment;

  generator  gen;
  driver     drv;
  monitor    mon;
  scoreboard sco;

  mailbox #(transaction) mbx_gen2drv;
  mailbox #(transaction) mbx_mon2sco;


  virtual uart_interface vif;

  
  //contructor
  function new(virtual uart_interface vif);
    this.vif = vif;
    
    mbx_gen2drv = new();
    mbx_mon2sco = new();

    gen = new(mbx_gen2drv);
    drv = new(mbx_gen2drv);
    mon = new(mbx_mon2sco);
    sco = new(mbx_mon2sco);

    drv.vif = this.vif;
    mon.vif = this.vif;

  endfunction
  int i = 0;
  
  //TASK
  task reset();
    drv.reset();
  endtask
  
  
  task test();
    fork 
      gen.run();
      drv.run(); // include reset
      mon.run();
      sco.run();    
    join_any
    $display("[ENV] finish run test");
  endtask
  
  task report();
    $display("--------------------------------------------------");
    $display("  DATA_IN_OUT:  TOTAL_DATA : %0d   PASS_DATA : %0d   FAIL_DATA : %0d", sco.total, sco.pass, sco.error);
    $display("--------------------------------------------------");
    $finish;
  endtask
  
  task run();
    reset();
    test();
    
    repeat(5) @(posedge vif.clk);
    wait(gen.count == sco.total);
      /*
      while(!(mbx_gen2drv.num() == 0 && mbx_mon2sco.num() == 0)) begin
        @(posedge vif.clk);
        i++;
        if( i > 3000) begin
          $display("[ENV] mbx_gen2drv.num() = %0d  mbx_mon2sco.num() = %0d",mbx_gen2drv.num(),mbx_mon2sco.num());
          $finish;
        end
      end*/
      //if ( mbx_gen2drv.num() == 0 && mbx_mon2sco.num() == 0) break;
    repeat(5) @(posedge vif.clk);
    report();
  endtask
  
  
endclass