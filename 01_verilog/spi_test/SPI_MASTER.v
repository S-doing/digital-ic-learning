`timescale 1ns/1ps

/*
    这个测试路径是 uart---》异步fifo----》SPI  使用AXI4 STEAM 握手协议
    RUN_MODE 0:  CPOL =0 CPHA =0 此时空闲态时，SCLK处于低电平，数据采样是在第1个边沿，也就是
                                 SCLK由低电平到高电平的跳变，所以数据采样是在上升沿，数据发送是在下降沿。
*/
module spi_master #(
    parameter RUN_MODE          = 0,     //MODE 0~3
    parameter DATA_WIDTH        = 8,
    parameter SCLK_DIV          = 8     // 2 4 8 16
)
(   
    input  wire                    clk,
    input  wire                    rst,

    /*
     * AXI input
     */
    input  wire [DATA_WIDTH-1:0]   s_axis_tdata,
    input  wire                    s_axis_tvalid,       //有数传入
    output wire                    s_axis_tready,       //数据可以接收

    // /*
    //  * AXI output
    //  */
    // output wire [DATA_WIDTH-1:0]   m_axis_tdata,
    // output wire                    m_axis_tvalid,       //有数据可以传出
    // input  wire                    m_axis_tready,       //


    /*
     * SPI MASTER tx
     */
    output wire                    sclk,
    output wire                    cs_n,
    output wire                    mosi,

    /*
     * SPI MASTER rx
     */
    input  wire                    miso,  

    output wire                    busy
);


    reg                           s_axis_tready_reg;
    // reg [DATA_WIDTH-1:0]          m_axis_tdata_reg;
    // reg                           m_axis_tvalid_reg;

    reg                           sclk_reg;
    reg                           cs_n_reg;
    reg                           mosi_reg;
    reg                           busy_reg;


    assign s_axis_tready    = s_axis_tready_reg;
    // assign m_axis_tdata     = m_axis_tdata_reg;
    // assign m_axis_tvalid    = m_axis_tvalid_reg;    
    assign sclk             = sclk_reg;
    assign cs_n             = cs_n_reg;
    assign mosi             = mosi_reg;
    assign busy             = busy_reg;

//  SCLK_DEPTH 必须是大于等于 2 的 2 的整数次幂
    parameter SCLK_WIDTH = $clog2(SCLK_DIV);
    reg [SCLK_WIDTH-0:0]          sclk_cnt;         //多预留一位 用于反转 0111 之前为一个状态 
    reg [DATA_WIDTH-1:0]          tx_data_reg;
    reg [3:0]                     tx_bit_cnt;
    reg [DATA_WIDTH-1:0]          rx_data_reg;
    reg [3:0]                     rx_bit_cnt;


    always @(posedge clk)begin
        if(rst)begin
            tx_data_reg <= 'b0;
            tx_bit_cnt <= 'b0;
            rx_data_reg <= 'b0;
            rx_bit_cnt <= 'b0;
            sclk_cnt <= 'b0;
            sclk_reg <= 'b0;
            mosi_reg <= 'b0;
            busy_reg <= 'b0;
            cs_n_reg <= 'b1;
            s_axis_tready_reg <= 'b1;            
        end else begin
            if (s_axis_tvalid && s_axis_tready && !busy_reg) begin        //有数据需要发送
                mosi_reg <= s_axis_tdata[DATA_WIDTH-1];
                tx_data_reg <= s_axis_tdata;
                tx_bit_cnt <= 'd8;                
                s_axis_tready_reg <= 'b0;
                cs_n_reg <= 'b0;                        
                busy_reg <= 'b1;

            end else if (tx_bit_cnt != 0)  begin          //开始数据交换
                sclk_cnt <= sclk_cnt + 'b1;
                if (sclk_cnt[SCLK_WIDTH-1:0] == SCLK_DIV -1 && sclk_cnt[SCLK_WIDTH] == 0) begin
                    sclk_reg <= 'b1;    //上升沿 读信号
                    rx_data_reg <= {rx_data_reg[DATA_WIDTH-2:0],miso};
                end else if (sclk_cnt[SCLK_WIDTH-1:0] == SCLK_DIV -1 && sclk_cnt[SCLK_WIDTH] == 1) begin
                    sclk_reg <= 'b0;    //下降沿 发信号
                    mosi_reg <= tx_data_reg[DATA_WIDTH-2];
                    tx_data_reg <= {tx_data_reg[DATA_WIDTH-2:0],1'b0};
                    tx_bit_cnt <= tx_bit_cnt - 'b1;
                end

            end else if ( !tx_bit_cnt && busy_reg )begin           //数据交换完毕
                sclk_cnt <= 'b0;
                sclk_reg <= 'b0;
                mosi_reg <= 'b0;
                busy_reg <= 'b0;
                cs_n_reg <= 'b1;
                s_axis_tready_reg <= 'b1;
            
            end

            // if (m_axis_tvalid && m_axis_tready) begin
            //     m_axis_tvalid_reg <= 'b0;
            // end
        end
    end




endmodule