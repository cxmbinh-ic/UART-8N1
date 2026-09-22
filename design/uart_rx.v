module uart_rx #(
    parameter DATA_WIDTH = 8,
    parameter OVERSAMPLE = 16
)(
    input clk,rst_n,
    input rx,
    input baud_tick_x16,
    output reg [DATA_WIDTH-1:0] rx_data_out,
    output reg rx_valid,
    output reg rx_error
);


////////CONTROL UNIT/////// RX FSM
//input of fsm datapath
reg [$clog2(OVERSAMPLE)-1:0] oversample_counter;
reg [$clog2(DATA_WIDTH)-1:0] rx_bit_counter;
reg                          rx_sync0,rx_sync1;
//output of fsm datapath
reg [DATA_WIDTH-1:0] rx_shift_reg;
//state of fsm
reg [2:0] state, next_state;
localparam IDLE = 3'b000, START = 3'b001, DATA = 3'b010, STOP = 3'b011, ERROR = 3'b100;
//the next of datapath
reg [$clog2(OVERSAMPLE)-1:0] next_oversample_counter;
reg [$clog2(DATA_WIDTH)-1:0] next_rx_bit_counter;
reg [DATA_WIDTH-1:0] next_rx_shift_reg;

//always ff for rx_sync
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        rx_sync0 <= 1'b1;
        rx_sync1 <= 1'b1;
    end
    else begin
        rx_sync0 <= rx;         // fix for metastability
        rx_sync1 <= rx_sync0;
    end
end



//always ff for next state
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        state <= IDLE;
        oversample_counter <= 0;
        rx_bit_counter <= 0;
        rx_data_out <= 0;
        next_oversample_counter <= 0;
        next_rx_bit_counter <= 0;
        next_rx_shift_reg <= 0;
    end
    else begin
        state <= next_state;
        oversample_counter <= next_oversample_counter;
        rx_bit_counter <= next_rx_bit_counter;
        rx_shift_reg <= next_rx_shift_reg;
    end
end
//always comb for next state logic
always @(*) begin
    case(state)
        IDLE: begin
            if(!rx_sync1) begin
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
            if((oversample_counter == OVERSAMPLE-1) && baud_tick_x16 && !rx_sync1) begin
                next_state = DATA;
            end
            else if((oversample_counter == OVERSAMPLE/2-1) && baud_tick_x16 && rx_sync1) begin
                next_state = IDLE;
            end
            else begin
                next_state = START;
            end
        end
        DATA: begin

            //next oversample counter and next rx bit counter
            if(baud_tick_x16) begin
                next_oversample_counter = oversample_counter + 1;
              
              if(oversample_counter == OVERSAMPLE/2-1) begin
                    next_rx_shift_reg[rx_bit_counter] = rx_sync1;
              end
              if(oversample_counter == OVERSAMPLE-1 && baud_tick_x16) begin
                    next_rx_bit_counter = next_rx_bit_counter + 1;
                
              end
              
            end
            else begin
                next_oversample_counter = oversample_counter;
              next_rx_bit_counter     = rx_bit_counter;
            end
            //next state
            if((oversample_counter == OVERSAMPLE-1) && baud_tick_x16 && rx_bit_counter == DATA_WIDTH-1) begin
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
            if((oversample_counter == OVERSAMPLE-1) && baud_tick_x16 && rx_sync1) begin
                next_state = IDLE;
            end
            else if((oversample_counter == OVERSAMPLE-1) && baud_tick_x16 && !rx_sync1) begin
                next_state = ERROR;
            end
            else begin
                next_state = STOP;
            end
        end
        ERROR: begin
            if(rx_sync1) begin
                next_state = IDLE;
            end
            else begin
                next_state = ERROR;
            end
        end
        default: next_state = IDLE;
    endcase
end

//always comb for output fsm
always @(*) begin
    rx_valid = 1'b0;
    rx_error = 1'b0;
    rx_data_out = 0;
    case(state)
        IDLE: begin
        end
        START: begin
        end
        DATA: begin
        end
        STOP: begin
            if((oversample_counter == OVERSAMPLE/2-1) && baud_tick_x16 && rx_sync1) begin
                rx_valid = 1'b1;
                rx_error = 1'b0;
                rx_data_out = rx_shift_reg;
            end
        end
        ERROR: begin
            if(rx_sync1) begin
                rx_valid = 1'b0;
                rx_error = 1'b0;
            end
            else begin
                rx_valid = 1'b0;
                rx_error = 1'b1;
            end
        end
        default: begin
            rx_valid = 1'b0;
            rx_error = 1'b0;
        end
    endcase
end
endmodule
