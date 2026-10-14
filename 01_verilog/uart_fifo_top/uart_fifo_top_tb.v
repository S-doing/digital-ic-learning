/*
    uart_fifo_top integrity test.
    test1 :Single-byte basic transmission.
    test2 :All-0 / All-1 boundary.
    test3 :Recive mid-stream reset.
*/

`timescale 1ns/1ps

module uart_fifo_top_tb ();


parameter DATA_WIDTH =  8;
parameter FIFO_DEPTH =  16;

reg                     clk;
reg                     rst;
reg                     rxd;
wire                    txd;

reg [15:0]              prescale;

uart_fifo_top#(
    .DATA_WIDTH(DATA_WIDTH),
    .FIFO_DEPTH(FIFO_DEPTH)
)u_uart_fifo_top(

    .clk(clk),
    .rst(rst),

    .rxd(rxd),
    .txd(txd),

    .prescale(prescale)        

);

initial begin
    clk = 0;
    forever #10 clk = ~clk; 
end

reg [3:0] rxd_cnt = 0;
/*
    test1 program
*/
task test1_program(input [DATA_WIDTH-1:0] data);begin
    @(negedge clk);
    rxd = 0;
    rxd_cnt = 0;
    repeat(5207)@(negedge clk);
    repeat(8)begin
        rxd = data[rxd_cnt];
        rxd_cnt = rxd_cnt +1;
        repeat(5207)@(negedge clk);
    end
    rxd_cnt = 0;
    rxd = 1;
    repeat(5207)@(negedge clk);
end 
endtask
/*
    test2 program
*/
task test2_program();begin
    #1000;
    test1_program(8'b1111_1111);
    #1000;
    test1_program(8'b0000_0000);
end 
endtask

/*
    test3 program
*/
task test3_program(input [DATA_WIDTH-1:0] data);begin
    @(negedge clk);
    rxd = 0;
    rxd_cnt = 0;
    repeat(5207)@(negedge clk);
    repeat(8)begin
        rxd = data[rxd_cnt];
        rxd_cnt = rxd_cnt +1;
        repeat(5207)@(negedge clk);
        if(rxd_cnt == 4)begin
            @(negedge clk);
            rst = 1;
            @(negedge clk);
            rst = 0;
        end
    end
    rxd = 1;
    repeat(5207)@(negedge clk);
end 
endtask



initial begin
    prescale = 651;
    rst = 1;
    #1000;
    @(negedge clk);
    rst = 0;
    #1000;
    test1_program(8'b0000_1111);
    #1000;
    test2_program();
    #1000;
    test3_program(8'b0110_1001);
    #1000000;

    $finish;
end


endmodule