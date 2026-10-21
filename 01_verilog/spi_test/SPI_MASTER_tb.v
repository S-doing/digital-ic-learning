`timescale 1ns / 1ps

module spi_master_tb();

    // ==========================================
    // 参数定义
    // ==========================================
    parameter DATA_WIDTH = 8;
    parameter SCLK_DIV   = 8; // 分频系数，SCLK周期 = 8*20ns = 160ns

    // ==========================================
    // 信号声明
    // ==========================================
    reg                    clk;
    reg                    rst;

    // AXI S端 (输入)
    reg  [DATA_WIDTH-1:0]  s_axis_tdata;
    reg                    s_axis_tvalid;
    wire                   s_axis_tready;

    // // AXI M端 (输出)
    // wire [DATA_WIDTH-1:0]  m_axis_tdata;
    // wire                   m_axis_tvalid;
    // reg                    m_axis_tready;

    // SPI 物理接口
    wire                   sclk;
    wire                   cs_n;
    wire                   mosi;
    reg                    miso;

    wire                   busy;

    // ==========================================
    // 实例化 DUT
    // ==========================================
    spi_master #(
        .DATA_WIDTH(DATA_WIDTH),
        .SCLK_DIV(SCLK_DIV)
    ) u_spi_master (
        .clk(clk),
        .rst(rst),
        .s_axis_tdata(s_axis_tdata),
        .s_axis_tvalid(s_axis_tvalid),
        .s_axis_tready(s_axis_tready),
        // .m_axis_tdata(m_axis_tdata),
        // .m_axis_tvalid(m_axis_tvalid),
        // .m_axis_tready(m_axis_tready),
        .sclk(sclk),
        .cs_n(cs_n),
        .mosi(mosi),
        .miso(miso),
        .busy(busy)
    );

    // ==========================================
    // 时钟生成 (50MHz)
    // ==========================================
    initial begin
        clk = 0;
        forever #10 clk = ~clk;
    end

    // ==========================================
    // 模拟 SPI 从机 (Slave) 的行为 (Mode 0)
    // ==========================================
    reg [7:0] slave_tx_data = 8'hA5; // 从机准备发给主机的数据
    reg [7:0] slave_rx_data = 0;     // 从机接收到的数据
    integer   bit_cnt = 0;

    always @(negedge cs_n) begin
        bit_cnt = 0;
    end

    // Mode 0: 从机在 SCLK 的下降沿改变 MISO 数据
    always @(negedge sclk) begin
        if (!cs_n) begin
            // 如果是第一个下降沿，准备发最高位 (提前放到 MISO 上)
            if (bit_cnt == 0) begin
                miso = slave_tx_data[7]; 
            end else begin
                miso = slave_tx_data[7 - bit_cnt];
            end
        end
    end

    // 从机在 SCLK 的上升沿采样 MOSI
    always @(posedge sclk) begin
        if (!cs_n) begin
            slave_rx_data[7 - bit_cnt] = mosi;
            bit_cnt = bit_cnt + 1;
            $display("[%0t] Slave 采样 MOSI bit[%0d] = %b", $time, 7-bit_cnt+1, mosi);
        end
    end

    // // ==========================================
    // // 模拟 AXI 接收端行为 (下游模块/FIFO)
    // // ==========================================
    // always @(posedge clk) begin
    //     m_axis_tready <= 1'b1; // 永远准备好接收
    //     if (m_axis_tvalid && m_axis_tready) begin
    //         $display("[%0t] Master 接收到了 MISO 数据: 0x%h", $time, m_axis_tdata);
    //     end
    // end

    // ==========================================
    // 主测试流程
    // ==========================================
    initial begin
        // 1. 初始化信号
        rst           = 1;
        s_axis_tvalid = 0;
        s_axis_tdata  = 0;
        // m_axis_tready = 1;
        miso          = 1; // 初始状态 MISO 为高

        // 2. 复位
        #100;
        rst = 0;
        #100;
        $display("========== 开始 SPI 传输 ==========");

        // 3. 模拟 AXI 发送数据 0x55
        @(negedge clk);
        s_axis_tdata  = 8'h55;
        s_axis_tvalid = 1;
        $display("[%0t] Master 准备发送: 0x55", $time);

        // 等待握手成功
        @(posedge clk); 
        while(!s_axis_tready) @(posedge clk);
        
        @(negedge clk);
        s_axis_tvalid = 0; // 数据已被接收，撤销 valid
        $display("[%0t] 握手成功，数据传输中...", $time);

        // 4. 等待传输结束
        wait(!busy);
        #1000;
        
        $display("[%0t] 从机最终收到的数据: 0x%h (期望 0x55)", $time, slave_rx_data);
        // $display("[%0t] 主机最终收到的数据: 0x%h (期望 0xA5)", $time, m_axis_tdata);
        $display("========== 传输结束 ==========");
        $finish;
    end

endmodule