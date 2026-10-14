`timescale 1ns/1ps

module uart_fifo_top #(
    parameter FIFO_DEPTH = 16,
    parameter DATA_WIDTH = 8
) (
    input   wire                        clk,
    input   wire                        rst,

    input   wire [15:0]                 prescale,
    

    input   wire                        rxd,
    output  wire                        txd

);
    
    // ==========================================
    // 内部 AXI-Stream 信号：FIFO -> TX
    // ==========================================
    wire [DATA_WIDTH-1 :0 ]             fifo2tx_s_tdata;
    wire                                fifo2tx_s_tvalid;
    wire                                fifo2tx_s_tready;

    uart_tx #(
        .DATA_WIDTH(DATA_WIDTH)
    )uart_fifo2tx(
        .clk(clk),
        .rst(rst),
        .s_axis_tdata(fifo2tx_s_tdata),
        .s_axis_tready(fifo2tx_s_tready),
        .s_axis_tvalid(fifo2tx_s_tvalid),
        .txd(txd),
        .prescale(prescale)
    );


    // ==========================================
    // 内部 AXI-Stream 信号：RX -> FIFO
    // ==========================================
    wire [DATA_WIDTH-1 : 0]             rx2fifo_m_tdata;
    wire                                rx2fifo_m_tvalid;
    wire                                rx2fifo_m_tready;

    uart_rx #(
        .DATA_WIDTH(DATA_WIDTH)
    ) uart_rx2fifo(
        .clk(clk),
        .rst(rst),
        .m_axis_tdata(rx2fifo_m_tdata),
        .m_axis_tready(rx2fifo_m_tready),
        .m_axis_tvalid(rx2fifo_m_tvalid),
        .rxd(rxd),
        .prescale(prescale)
    );

    // ==========================================
    // FIFO 实例化（AXI 从输入，AXI 主输出）
    // ==========================================

    sync_axis_fifo #(
        .DATA_WIDTH(DATA_WIDTH),
        .FIFO_DEPTH(FIFO_DEPTH)
    )u_fifo(
        .clk(clk),
        .rst(rst),        
        .s_axis_tdata(rx2fifo_m_tdata),
        .s_axis_tready(rx2fifo_m_tready),
        .s_axis_tvalid(rx2fifo_m_tvalid),

        .m_axis_tdata(fifo2tx_s_tdata),
        .m_axis_tready(fifo2tx_s_tready),
        .m_axis_tvalid(fifo2tx_s_tvalid)
    );


endmodule