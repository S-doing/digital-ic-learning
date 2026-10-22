`timescale 1ns/1ps
module async_axis_fifo_tb ();
    
    parameter DATA_WIDTH = 8;
    parameter FIFO_DEPTH = 32;
    parameter PTR_WIDTH  = $clog2(FIFO_DEPTH);    

    reg                             s_clk;
    reg                             s_rst;
    reg   [DATA_WIDTH-1:0]          s_axis_tdata;
    reg                             s_axis_tvalid;
    wire                            s_axis_tready;

    reg                             m_clk;
    reg                             m_rst;
    wire   [DATA_WIDTH-1:0]         m_axis_tdata;
    wire                            m_axis_tvalid;
    reg                             m_axis_tready;

    // 用于自动对比的队列
    reg [DATA_WIDTH-1:0] expected_mem [0 : 1023]; 
    integer wr_cnt = 0;
    integer rd_cnt = 0;
    integer err_cnt = 0;

    async_axis_fifo #(
        .DATA_WIDTH(DATA_WIDTH),
        .FIFO_DEPTH(FIFO_DEPTH),
        .PTR_WIDTH(PTR_WIDTH)
    ) u_async_axis_fifo (
        .s_clk(s_clk), .s_rst(s_rst),
        .s_axis_tdata(s_axis_tdata), .s_axis_tvalid(s_axis_tvalid), .s_axis_tready(s_axis_tready),
        .m_clk(m_clk), .m_rst(m_rst),
        .m_axis_tdata(m_axis_tdata), .m_axis_tvalid(m_axis_tvalid), .m_axis_tready(m_axis_tready)
    );

    // 50MHz 写时钟
    initial begin s_clk = 0; forever #10 s_clk = ~s_clk; end
    // 200MHz 读时钟
    initial begin m_clk = 0; forever #2.5 m_clk = ~m_clk; end

    // ==========================================
    // 工业级 AXI 写入 Task (带反压阻塞机制)
    // ==========================================
    task write_data(input integer cnt);
        integer i;
        begin
            for (i = 0; i < cnt; i = i + 1) begin
                @(negedge s_clk);
                s_axis_tdata  = $random; // 产生随机数据
                s_axis_tvalid = 1;
                
                // 必须等到 tready 为 1 才算握手成功
                @(posedge s_clk); 
                while(!s_axis_tready) @(posedge s_clk);
                
                // 记入预期队列
                expected_mem[wr_cnt] = s_axis_tdata;
                wr_cnt = wr_cnt + 1;
                
                @(negedge s_clk);
                s_axis_tvalid = 0;
            end
        end
    endtask

    // ==========================================
    // 读端持续消费机制 (模拟下游不断取数)
    // ==========================================
    reg rd_enable = 0;
    always @(posedge m_clk) begin
        if (!m_rst && rd_enable) begin
            // 核心修改 1：无条件拉高 ready，表示随时准备好接收
            m_axis_tready <= 1; 
            
            // 核心修改 2：必须在 valid 和 ready 同时为 1 的那一拍才读取数据！
            if (m_axis_tvalid && m_axis_tready) begin 
                // 自动比对校验
                if (m_axis_tdata !== expected_mem[rd_cnt]) begin
                    $display("[ERROR] 数据不匹配! 时间: %0t, 期望: %h, 实际: %h", $time, expected_mem[rd_cnt], m_axis_tdata);
                    err_cnt = err_cnt + 1;
                end else begin
                    $display("[PASS] 读入正确: %h", m_axis_tdata);
                end
                rd_cnt = rd_cnt + 1;
            end
        end else begin
            m_axis_tready <= 0;
        end
    end

    // ==========================================
    // 主测试流程
    // ==========================================
    initial begin
        s_rst = 1; m_rst = 1;
        s_axis_tvalid = 0; m_axis_tready = 0;
        #1000;
        s_rst = 0; m_rst = 0;
        #1000;

        // --------------------------------------------------
        // 测试 1：基本写入与读出验证（数据比对）
        // --------------------------------------------------
        $display("\n=== Test 1: 基本写入与读出 ===");
        write_data(10);
        rd_enable = 1; // 开启读端消费
        #500;
        
        // --------------------------------------------------
        // 测试 2：写入超过深度的数据，测试 Full 反压
        // --------------------------------------------------
        $display("\n=== Test 2: 测试 FIFO Full 反压 ===");
        write_data(50); // 深度只有 32，连续写 50 个，看看会不会丢数
        #2000;
        
        // --------------------------------------------------
        // 测试 3：读空后继续读，测试 Empty 保护
        // --------------------------------------------------
        $display("\n=== Test 3: 测试 FIFO Empty ===");
        // 目前数据已经被读完
        @(negedge m_clk);
        m_axis_tready = 1;
        repeat(5) @(negedge m_clk);
        m_axis_tready = 0;
        $display("读空后 tready 置 1，检查 tvalid 是否为 0，且无数据输出");
        
        // --------------------------------------------------
        // 测试 4：并发读写测试 (边写边读)
        // --------------------------------------------------
        $display("\n=== Test 4: 并发异步读写 ===");
        fork
            write_data(30); // 写端持续写
            begin           // 读端持续读
                rd_enable = 1;
                #1000;
            end
        join
        
        #5000;
        $display("\n==================================");
        if (err_cnt == 0)
            $display("测试全部通过！Total Write: %0d, Total Read: %0d", wr_cnt, rd_cnt);
        else
            $display("测试失败！共有 %0d 个错误。", err_cnt);
        $display("==================================");
        $finish;
    end

endmodule