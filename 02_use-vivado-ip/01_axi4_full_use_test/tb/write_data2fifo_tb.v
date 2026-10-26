`timescale 1ns/1ps

module tb_write_data2fifo();

    // 1. 信号定义
    reg          clk;
    reg          rst_n;
    reg          write_en;
    reg  [127:0] user_data;

    // 观察 DUT 产生的 AXI 信号
    wire [31:0]  m_axi_awaddr;
    wire [7:0]   m_axi_awlen;
    wire [2:0]   m_axi_awsize;
    wire [1:0]   m_axi_awburst;
    wire         m_axi_awvalid;
    wire         m_axi_awready; // 由 IP 输出

    wire [31:0]  m_axi_wdata;
    wire [3:0]   m_axi_wstrb;
    wire         m_axi_wlast;
    wire         m_axi_wvalid;
    wire         m_axi_wready;  // 由 IP 输出

    wire [1:0]   m_axi_bresp;
    wire         m_axi_bvalid;  // 由 IP 输出
    wire         m_axi_bready;

    // 2. 实例化你的模块
    write_data2fifo u_dut (
        .clk(clk),
        .rst_n(rst_n),
        .write_en(write_en),
        .user_data(user_data),
        
        .m_axi_awaddr(m_axi_awaddr),
        .m_axi_awlen(m_axi_awlen),
        .m_axi_awsize(m_axi_awsize),
        .m_axi_awburst(m_axi_awburst),
        .m_axi_awvalid(m_axi_awvalid),
        .m_axi_awready(m_axi_awready),
        
        .m_axi_wdata(m_axi_wdata),
        .m_axi_wstrb(m_axi_wstrb),
        .m_axi_wlast(m_axi_wlast),
        .m_axi_wvalid(m_axi_wvalid),
        .m_axi_wready(m_axi_wready),
        
        .m_axi_bresp(m_axi_bresp),
        .m_axi_bvalid(m_axi_bvalid),
        .m_axi_bready(m_axi_bready)
    );

    // 3. 生成 50MHz 时钟 (周期 20ns)
    initial begin
        clk = 0;
        forever #10 clk = ~clk;
    end

    // 4. 主测试流程
    initial begin
        // 初始化信号
        rst_n     = 0;
        write_en  = 0;
        // 准备写入的 4 个 32-bit 数据：从左到右分别是 4444, 3333, 2222, 1111
        user_data = 128'h44444444_33333333_22222222_11111111;

        // 保持复位 100ns
        #100;
        rst_n = 1;
        #50;

        $display("[%0t] 释放复位，准备发起 AXI 写请求...", $time);

        // 产生一个时钟周期的写脉冲
        @(negedge clk);
        write_en = 1;
        @(negedge clk);
        write_en = 0;

        // 等待足够长的时间，让 AXI 握手和状态机跑完
        #1000; 
        
        $display("[%0t] 仿真结束，请观察波形。", $time);
        $finish;
    end

endmodule