module uart_tx #(
    parameter DATA_WIDTH = 8,
    parameter OVERSAMPLE = 16
)(
    input clk,rst_n,
    input [DATA_WIDTH-1:0] data_in,
    input tx_valid,
    input baud_tick_x16,
    output reg tx_ready,
    output reg tx_busy,
    output reg tx
);

//module instantiation of baud_rate_generator



///////CONTROL UNIT/////// TX FSM 
//input of fsm
reg [$clog2(OVERSAMPLE)-1:0] oversample_counter;
reg [$clog2(DATA_WIDTH)-1:0] tx_bit_counter;
//state of fsm
reg [1:0] state, next_state;
//next for counter
reg [$clog2(OVERSAMPLE)-1:0] next_oversample_counter;
reg [$clog2(DATA_WIDTH)-1:0] next_tx_bit_counter;
localparam IDLE = 2'b00, START = 2'b01, DATA = 2'b10, STOP = 2'b11;

//always ff for next state
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        state <= IDLE;
        oversample_counter <= 0;
        tx_bit_counter <= 0;
        next_oversample_counter <= 0;
        next_tx_bit_counter <= 0;
    end
    else begin
        state <= next_state;
        oversample_counter <= next_oversample_counter;
        tx_bit_counter <= next_tx_bit_counter;
    end
end
//always comb for next state logic
always @(*) begin
    case(state)
        IDLE: begin
            if(tx_valid) begin
                next_state = START;
            end
            else begin
                next_state = IDLE;
            end
        end
        START: begin
            //next oversample counter
            if(baud_tick_x16) begin
                next_oversample_counter = oversample_counter + 1;
            end
            else begin
                next_oversample_counter = oversample_counter;
            end

            //next state
            if((oversample_counter == OVERSAMPLE-1) && baud_tick_x16) begin
                next_state = DATA;
            end
            else begin
                next_state = START;
            end
        end
        DATA: begin

            //next oversample counter and next tx bit counter
            if(baud_tick_x16) begin
                next_oversample_counter = oversample_counter + 1;
                if(oversample_counter == OVERSAMPLE-1) begin
                    next_tx_bit_counter = tx_bit_counter + 1;
                end
                else begin
                    next_tx_bit_counter = tx_bit_counter;
                end
            end
            else begin
                next_oversample_counter = oversample_counter;
              next_tx_bit_counter = tx_bit_counter;
              
            end
            //next state
            if((oversample_counter == OVERSAMPLE-1) && baud_tick_x16 && tx_bit_counter == DATA_WIDTH-1) begin
                next_state = STOP;
            end
            else begin
                next_state = DATA;
            end
        end
        STOP: begin
            //next oversample counter
            if(baud_tick_x16) begin
                next_oversample_counter = oversample_counter + 1;
            end
            else begin
                next_oversample_counter = oversample_counter;
            end
            //next state
            if((oversample_counter == OVERSAMPLE-1) && baud_tick_x16) begin
                next_state = IDLE;
            end
            else begin
                next_state = STOP;
            end
        end
        default: next_state = IDLE;
    endcase
end

//always comb for output fsm
always @(*) begin
    case(state)
        IDLE: begin
            tx = 1'b1;
            tx_ready = 1'b1;
            tx_busy = 1'b0;
        end
        START: begin
            tx = 1'b0;
            tx_ready = 1'b0;
            tx_busy = 1'b1;
        end
        DATA: begin
            tx = data_in[tx_bit_counter];
            tx_ready = 1'b0;
            tx_busy = 1'b1;
        end
        STOP: begin
            tx = 1'b1;
            tx_ready = 1'b0;
            tx_busy = 1'b1;
        end
        default: begin
            tx = 1'b1;
            tx_ready = 1'b0;
            tx_busy = 1'b0;
        end
    endcase
end

endmodule