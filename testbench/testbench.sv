`timescale 1ns/1ps
`include "interface.sv"
`include "transaction.sv"
`include "generator.sv"
`include "driver.sv"
`include "monitor.sv"
`include "scoreboard.sv"
`include "environment.sv"
module tb_uart_top;

  localparam DATA_WIDTH = 8;
  localparam CLK_PERIOD_NS = 20;   // 50MHz clock (1/50MHz = 20ns)
  localparam BAUD_RATE = 115200;
  localparam FREQUENCY = 50000000; // 50MHz clock frequency
  localparam OVERSAMPLE = 16;
  
  logic clk;
  
  initial begin
  #50;
  $display("[%0t] Top-level clock check: clk = %0b", $time, clk);
end

  
  uart_interface uif(.clk(clk));

  uart_top #(
    .DATA_WIDTH(DATA_WIDTH),
    .OVERSAMPLE(OVERSAMPLE)
  ) dut (
    .clk        (uif.clk),
    .rst_n      (uif.rst_n),
    .rx         (uif.tx),   // loopback goes here
    .tx_valid   (uif.tx_valid),
    .tx_data_in (uif.tx_data_in),
    .tx         (uif.tx),
    .tx_ready   (uif.tx_ready),
    .tx_busy    (uif.tx_busy),
    .rx_data_out(uif.rx_data_out),
    .rx_valid   (uif.rx_valid),
    .rx_error   (uif.rx_error)
  );
  
  initial begin
    clk = 0;
  end
  always #(CLK_PERIOD_NS/2) clk = ~clk;
  
  environment env;
  
  initial begin
    env = new(uif);
    env.gen.count = 10;
    env.run();
  end







//Waveform dump
initial begin
  $dumpfile("tb_uart.vcd");
  $dumpvars(0, tb_uart_top);
end
  
  


endmodule