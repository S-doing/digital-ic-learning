/*
    test1 ： write 1 byte to fifo
    test2 :  Fill the FIFO to capacity
    test3 :  read n byte form fifo
    test4 ： Simultaneously write data to and read data from the FIFO.
*/

`timescale 1ns/1ps

module sync_axis_fifo_tb ();
    
    parameter DATA_WIDTH = 8;
    parameter FIFO_DEPTH = 16;

    reg [DATA_WIDTH-1:0]    s_axis_tdata;
    reg                     clk;
    reg                     rst;
    reg                     s_axis_tvalid;
    reg                     m_axis_tready;

    wire [DATA_WIDTH-1:0]   m_axis_tdata;
    wire                    m_axis_tvalid;
    wire                    s_axis_tready;

sync_axis_fifo #(
    .DATA_WIDTH(DATA_WIDTH),
    .FIFO_DEPTH(FIFO_DEPTH)
) u_sync_axis_fifo(
    .clk(clk),
    .rst(rst),
    .s_axis_tdata(s_axis_tdata),
    .s_axis_tvalid(s_axis_tvalid),
    .s_axis_tready(s_axis_tready),
    .m_axis_tdata(m_axis_tdata),
    .m_axis_tvalid(m_axis_tvalid),
    .m_axis_tready(m_axis_tready)
);  

initial begin
    clk = 0;
    forever #10 clk = ~clk;
end
/*
    test1_program s_axis_tready =1, 将数据写入s_axis_tdata 拉高valid信号线 将数据写入fifo
*/
task test1_program(input [DATA_WIDTH-1 :0]data);begin
    @(negedge clk);
    s_axis_tdata  = data;
    @(negedge clk);
    s_axis_tvalid = 1;
    @(negedge clk);
    s_axis_tvalid = 0;
end
endtask

/*
    test2_program
*/
reg [DATA_WIDTH-1 :0] num ;
task test2_program();begin

    num = 'b1111_1111;
    repeat(FIFO_DEPTH)begin
        test1_program(num);
        num = num - 1;        
    end

end
endtask


reg [DATA_WIDTH-1 :0] fifo_cache [0 :FIFO_DEPTH-1];
reg [$clog2(FIFO_DEPTH)-1 :0] rd_cnt;
/*
    test3_program
*/
task test3_program(input [$clog2(FIFO_DEPTH)-1 :0]cnt);begin
    repeat(cnt)begin

        @(negedge clk);
        m_axis_tready = 1;
        @(negedge clk);
        m_axis_tready = 0;        
    end
end
endtask

/*
    test4_program
*/
task test4_program();begin
    @(negedge clk);
    rst = 1;
    @(negedge clk);
    rst = 0;
    num = 'b1111_1111;
    repeat(256)begin
        test1_program(num);
        test3_program(1);
        num = num - 1;        
    end
end
endtask




initial begin
    rd_cnt = 0;
    s_axis_tvalid = 0;
    rst = 1;
    #1000;
    rst = 0;
    #1000;
    test1_program(8'b1111_0000);
    #1000;
    test2_program();
    #1000;
    test3_program(7);
    #1000;
    test4_program();
    #1000;



    $finish;
end




endmodule