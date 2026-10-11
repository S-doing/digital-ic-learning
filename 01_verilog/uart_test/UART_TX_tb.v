/*
    UART_TX integrity test.
    test1:  Single-byte basic transmission.
    test2:  All-0 / All-1 boundary.
    test3:  Data bit order (LSB first).
    test4:  Send mid-stream reset.
    test5:  `start` is triggered repeatedly during the sending process.
*/

`timescale 1ns / 1ps
module uart_tx_tb();

parameter DATA_WIDTH = 8;
reg         clk;
reg         rst;
reg         [DATA_WIDTH-1:0] s_axis_tdata;
reg         s_axis_tvalid;
wire        s_axis_tready;
wire        txd;
wire        busy;
reg [15:0]  prescale;

uart_tx #(
    .DATA_WIDTH(DATA_WIDTH)
)   uart_tx_u(
    .clk(clk),
    .rst(rst),
    .s_axis_tdata(s_axis_tdata),
    .s_axis_tvalid(s_axis_tvalid),
    .s_axis_tready(s_axis_tready),
    .txd(txd),
    .busy(busy),
    .prescale(prescale)
);

initial begin
    clk = 0;
    forever #10 clk = ~clk;   //sys_clk = 50Mhz
end

/*
    test1 program
    Theoretically, transmitting one byte of data at a baud rate of 9600 takes 1041.6 µs.
    Testing in simulation software shows that transmitting one byte of data takes 1043.65 µs.
*/

task test1_program( input [DATA_WIDTH-1:0] data);begin
    @(negedge clk);
    s_axis_tdata = data;
    s_axis_tvalid = 1;
    @(negedge clk);
    s_axis_tvalid = 0;
    wait(s_axis_tready == 1);
    $display("data sent successfully. test1 success");
end
endtask


/*
    test2 program
*/

task test2_program();begin
    test1_program(8'b0000_0000);
    #1000;
    test1_program(8'b1111_1111);
    #1000;
end
endtask

/*
    test3 program
*/

task test3_program();begin
    test1_program(8'b1000_0000);
    #1000;
end
endtask

/*
    test4 program
*/

task test4_program( input [DATA_WIDTH-1:0] data);begin
    @(negedge clk);
    s_axis_tdata = data;
    s_axis_tvalid = 1;
    @(negedge clk);
    s_axis_tvalid = 0;
    #5000;
    @(negedge clk);
    rst = 1;
    @(negedge clk);
    rst = 0;
    wait(s_axis_tready == 1);
end
endtask

/*
    test5 program
*/

task test5_program( input [DATA_WIDTH-1:0] data);begin
    @(negedge clk);
    s_axis_tdata = data;
    s_axis_tvalid = 1;
    @(negedge clk);
    s_axis_tvalid = 0;
    #10000;
    @(negedge clk);
    s_axis_tvalid = 1;
    @(negedge clk);
    s_axis_tvalid = 0;
    wait(s_axis_tready == 1);
end
endtask



initial begin
    prescale = 651;              // 50M/9600/8 = 651    
    rst = 1;
    #10;
    rst = 0;

    test1_program(8'b1001_1001);
    #1000;
    test2_program;
    #1000;
    test3_program;
    #1000;
    test4_program(8'b1111_0000);
    #1000;
    test5_program(8'b0000_1111);
    #1000;
    $finish;
end



    
endmodule

