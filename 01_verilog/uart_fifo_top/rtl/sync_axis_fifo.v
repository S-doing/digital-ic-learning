`timescale 1ns/1ps
module sync_axis_fifo #(
    parameter  DATA_WIDTH = 8,
    parameter  FIFO_DEPTH = 16
) (
    // 公共时钟与复位
    input                    clk,
    input                    rst,

    // AXI4-Stream 输入端：写入 FIFO
    input   [DATA_WIDTH-1:0] s_axis_tdata,
    input                    s_axis_tvalid,
    output                   s_axis_tready,

    // AXI4-Stream 输出端：读取 FIFO
    output  [DATA_WIDTH-1:0] m_axis_tdata,
    output                   m_axis_tvalid,
    input                    m_axis_tready
);
// FIFO_DEPTH 必须是大于等于 2 的 2 的整数次幂
    parameter PTR_WIDTH =  $clog2(FIFO_DEPTH);

    reg [DATA_WIDTH-1 :0] ram_fifo [0 :FIFO_DEPTH-1];


//==============================================
// 1. 空满判断
//==============================================
    wire fifo_wr_full;
    wire fifo_rd_empty;

    reg [PTR_WIDTH-0 :0]    wr_ptr = 'b0;
    reg [PTR_WIDTH-0 :0]    rd_ptr = 'b0;

    assign fifo_wr_full   = (wr_ptr[PTR_WIDTH] != rd_ptr[PTR_WIDTH] && wr_ptr[PTR_WIDTH-1 :0] == rd_ptr[PTR_WIDTH-1 :0]);
    assign fifo_rd_empty  = (wr_ptr == rd_ptr);


//==============================================
// 2. AXI4-Stream 握手
//==============================================
    assign s_axis_tready  = !fifo_wr_full;
    assign m_axis_tvalid  = !fifo_rd_empty;

    assign m_axis_tdata   = fifo_rd_empty ? {DATA_WIDTH{1'b0}} : ram_fifo[rd_ptr[PTR_WIDTH-1:0]];


    
//==============================================
// 3. 写入和读取控制
//==============================================

    //wr
    wire   wr_en;
    assign wr_en  = (s_axis_tvalid && s_axis_tready);
    //rd
    wire   rd_en;
    assign rd_en  = (m_axis_tvalid && m_axis_tready);

    //wr
    always @(posedge clk)begin
        if(rst)begin
            wr_ptr  <= 'b0;
        end else begin
            if(wr_en && !fifo_wr_full) begin
                ram_fifo[wr_ptr[PTR_WIDTH-1:0]] <= s_axis_tdata;
                wr_ptr   <= wr_ptr + 'b1;
                     $display("[%0t] FIFO WRITE: addr=%0d, data=%02h", 
                     $time, wr_ptr[PTR_WIDTH-1:0], s_axis_tdata);
            end
        end
    end

    //rd
    always @(posedge clk)begin
        if(rst)begin
            rd_ptr  <= 'b0;
        end else begin
            if(rd_en && !fifo_rd_empty) begin                   //握手成功 表示已经将上一个数据发送 开始读取下一个数据
                rd_ptr  <= rd_ptr + 'b1;
            end 
        end 
    end


endmodule