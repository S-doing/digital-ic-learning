/*
    UART_RX integrity test.
    test1 :Single-byte basic transmission.
    test2 :All-0 / All-1 boundary.
    test3 :Data bit order (LSB first).
    test4 :Recive mid-stream reset.
    test5 :Insufficient start bit hold time
*/

`timescale 1ns/1ps

module uart_rx_tb ();

parameter DATA_WIDTH = 8;

reg                     clk;
reg                     rst;
wire [DATA_WIDTH-1:0]   m_axis_tdata;             
wire                    m_axis_tvalid;    
reg                     m_axis_tready;

reg                     rxd;
wire                    busy;
wire                    overrun_error;
wire                    frame_error;

reg [15:0]              prescale;


uart_rx #(
    .DATA_WIDTH(DATA_WIDTH)    
)u_uart_rx(
    .clk(clk),
    .rst(rst),
    .m_axis_tdata(m_axis_tdata),
    .m_axis_tvalid(m_axis_tvalid),
    .m_axis_tready(m_axis_tready),
    .rxd(rxd),
    .busy(busy),
    .overrun_error(overrun_error),
    .frame_error(frame_error),
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
    rxd = 1;
    repeat(5207)@(negedge clk);
    wait(busy == 0);
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
task test3_program();begin
    #1000;
    test1_program(8'b1000_0000);
end 
endtask

/*
    test4 program
*/
task test4_program(input [DATA_WIDTH-1:0] data);begin
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
    wait(busy == 0);
end 
endtask

/*
    test5 program
*/
task test5_program(input [DATA_WIDTH-1:0] data);begin
    @(negedge clk);
    rxd = 0;
    rxd_cnt = 0;
    repeat(1000)@(negedge clk);
    rxd = 1;
    repeat(8)begin
        rxd = data[rxd_cnt];
        rxd_cnt = rxd_cnt +1;
        repeat(5207)@(negedge clk);
    end
    rxd = 1;
    repeat(5207)@(negedge clk);
end 
endtask




initial begin
    prescale = 651;
    m_axis_tready = 1;
    rst = 1;
    #1000;
    @(negedge clk);
    rst = 0;
    #1000;
    test1_program(8'b0000_1111);
    #1000;
    test2_program;
    #1000;
    test3_program;
    #1000;
    test4_program(8'b1111_1111);
    #1000;
    test5_program(8'b1111_1111);
    #1000;
    $finish;
end





endmodule