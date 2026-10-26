module fifo_sync
    // Parameters section
  #( parameter FIFO_DEPTH = 8,
	   parameter DATA_WIDTH = 32)
    // Ports section   
	(input clk, 
     input rst_n,
     input cs,     // chip select	 
     input wr_en, 
     input rd_en, 
     input [DATA_WIDTH-1:0] data_in, 
     output reg [DATA_WIDTH-1:0] data_out, 
	 output empty,
	 output full); 

  localparam FIFO_DEPTH_LOG = $clog2(FIFO_DEPTH);// if fifo_depth is 8 : this gives you 3 as value
	
    // Declare a by-dimensional array to store the data
  reg [DATA_WIDTH-1:0] fifo [0:FIFO_DEPTH-1];// depth 8 => [0:7] 32 bit elements
	
	// Wr/Rd pointer have 1 extra bits at MSB
  reg [FIFO_DEPTH_LOG:0] write_pointer;//3:0 : 4 bits
  reg [FIFO_DEPTH_LOG:0] read_pointer;//3:0 : 4 bits

  //write
    always @(posedge clk or negedge rst_n) 
      begin
      if(!rst_n)//rst =0 system reset happens
		    write_pointer <= 0;
      else if (cs && wr_en && !full) begin
          fifo[write_pointer[FIFO_DEPTH_LOG-1:0]] <= data_in;
	    //if (write_pointer == FIFO_DEPTH-1)
          //   write_pointer <= 0;
      //else
        write_pointer <= write_pointer + 1'b1;
      end
      end
  
	//read
	always @(posedge clk or negedge rst_n) 
      begin
	    if(!rst_n)
		    read_pointer <= 0;
      else if (cs && rd_en && !empty) begin
          	data_out <= fifo[read_pointer[FIFO_DEPTH_LOG-1:0]];
	        
       //if (read_pointer == FIFO_DEPTH-1)
       //read_pointer <= 0;
       // else
        read_pointer <= read_pointer + 1'b1;
      end
	end
	
	// Declare the empty/full logic
    assign empty = (read_pointer == write_pointer);
	assign full  = (read_pointer == {~write_pointer[FIFO_DEPTH_LOG], write_pointer[FIFO_DEPTH_LOG-1:0]});

  
  /*
    always @(posedge clk) begin
	    if (cs && wr_en && !full)
	        fifo[write_pointer[FIFO_DEPTH_LOG-1:0]] <= data_in;
	end
	
	always @(posedge clk or negedge rst_n) begin
	    if (!rst_n)
		    data_out <= 0;
		else if (cs && rd_en && !empty)
	        data_out <= fifo[read_pointer[FIFO_DEPTH_LOG-1:0]];
	end
*/
endmodule
