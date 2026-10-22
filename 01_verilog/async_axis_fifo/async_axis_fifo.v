`timescale 1ns/1ps

module async_axis_fifo #(
    parameter DATA_WIDTH = 8,
// FIFO_DEPTH 必须是大于等于 4 的 2 的整数次幂
    parameter FIFO_DEPTH = 16,
    parameter PTR_WIDTH = $clog2(FIFO_DEPTH)    
) (
    input                             s_clk,
    input                             s_rst,
// AXI4-Stream 输入端
    input   [DATA_WIDTH-1:0]          s_axis_tdata,
    input                             s_axis_tvalid,
    output                            s_axis_tready,



    input                             m_clk,
    input                             m_rst,
// AXI4-Stream 输出端
    output   [DATA_WIDTH-1:0]         m_axis_tdata,
    output                            m_axis_tvalid,
    input                             m_axis_tready
);


    reg [DATA_WIDTH-1 :0]fifo_buff[0: FIFO_DEPTH -1];


// write
    reg  [PTR_WIDTH-0:0]  wr_ptr;
    reg  [PTR_WIDTH-0:0]  rd_gray_ptr_d0;
    reg  [PTR_WIDTH-0:0]  rd_gray_ptr_d1;
    wire [PTR_WIDTH-0:0]  wr_gray_ptr;
    wire                  wr_en;
    wire                  fifo_full;


    assign wr_gray_ptr   = (wr_ptr >> 1)^wr_ptr;
    assign fifo_full     = ((wr_gray_ptr[PTR_WIDTH]     != rd_gray_ptr_d1[PTR_WIDTH])&&
                            (wr_gray_ptr[PTR_WIDTH-1]   != rd_gray_ptr_d1[PTR_WIDTH-1])&&
                            (wr_gray_ptr[PTR_WIDTH-2:0] == rd_gray_ptr_d1[PTR_WIDTH-2:0]));
    assign s_axis_tready = !fifo_full;
    assign wr_en         = (s_axis_tvalid && s_axis_tready);

// read
    reg  [PTR_WIDTH-0:0]  rd_ptr;
    reg  [PTR_WIDTH-0:0]  wr_gray_ptr_d0;
    reg  [PTR_WIDTH-0:0]  wr_gray_ptr_d1;
    wire [PTR_WIDTH-0:0]  rd_gray_ptr;
    wire                  rd_en;
    wire                  fifo_empty;



    assign rd_gray_ptr   = (rd_ptr >> 1)^rd_ptr;
    assign fifo_empty    = (rd_gray_ptr == wr_gray_ptr_d1);
    assign m_axis_tvalid = !fifo_empty;
    assign rd_en         = (m_axis_tvalid && m_axis_tready);
    assign m_axis_tdata  = fifo_buff[rd_ptr[PTR_WIDTH-1:0]];
/*
    写时钟域
*/
    always @(posedge s_clk) begin
        if (s_rst) begin                
            rd_gray_ptr_d0 <= 'b0;
            rd_gray_ptr_d1 <= 'b0;            
        end else begin
            rd_gray_ptr_d0 <= rd_gray_ptr;
            rd_gray_ptr_d1 <= rd_gray_ptr_d0;
        end
    end

    always @(posedge s_clk) begin
        if (s_rst) begin
            wr_ptr <= 'b0;
        end else begin
            if(wr_en && !fifo_full)begin
                fifo_buff[wr_ptr[PTR_WIDTH-1:0]] <= s_axis_tdata;
                wr_ptr <= wr_ptr + 'b1;
            end 
        end
    end

/*
    读时钟域
*/
    always @(posedge m_clk) begin
        if (m_rst) begin
            wr_gray_ptr_d0 <= 'b0;
            wr_gray_ptr_d1 <= 'b0;
        end else begin
            wr_gray_ptr_d0 <= wr_gray_ptr;
            wr_gray_ptr_d1 <= wr_gray_ptr_d0;
        end
    end

    always @(posedge m_clk) begin
        if (m_rst) begin
            rd_ptr <= 'b0;
        end else begin
            if(rd_en && !fifo_empty)begin
                rd_ptr <= rd_ptr + 'b1;
            end            
        end
    end



endmodule