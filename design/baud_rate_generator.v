module baud_rate_generator
#(
    parameter BAUD_RATE = 115200,
    parameter CLK_FREQ = 50000000,
    parameter OVERSAMPLE = 16,
    parameter BAUD_DIV = CLK_FREQ / (BAUD_RATE*OVERSAMPLE)
)(
    input clk,rst_n,
    output reg baud_tick_x16
);

reg [$clog2(BAUD_DIV)-1:0] baud_counter;

always @(posedge clk or negedge rst_n) begin

    if(!rst_n) begin
        baud_counter <= 0;
        baud_tick_x16 <= 0;
    end
    else begin
        if(baud_counter == BAUD_DIV-1) begin
            baud_counter <= 0;
            baud_tick_x16 <= 1;
        end
        else begin
            baud_counter <= baud_counter + 1;
            baud_tick_x16 <= 0;
        end
    end
end

endmodule