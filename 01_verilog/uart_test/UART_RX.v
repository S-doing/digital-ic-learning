`timescale 1ns / 1ps

/*
 * AXI4-Stream UART
 */
module uart_rx #
(
    parameter DATA_WIDTH = 8
)
(
    input  wire                   clk,
    input  wire                   rst,

    /*
     * AXI output
     */
    output wire [DATA_WIDTH-1:0]  m_axis_tdata,
    output wire                   m_axis_tvalid,
    input  wire                   m_axis_tready,

    /*
     * UART interface
     */
    input  wire                   rxd,

    /*
     * Status
     */
    output wire                   busy,
    output wire                   overrun_error,
    output wire                   frame_error,

    /*
     * Configuration
     */
    input  wire [15:0]            prescale
);

reg [DATA_WIDTH-1:0] m_axis_tdata_reg  = 'b0;
reg                  m_axis_tvalid_reg = 1'b0;

reg rxd_reg = 1'b1;

reg busy_reg          = 1'b0;
reg overrun_error_reg = 1'b0;
reg frame_error_reg   = 1'b0;

reg [DATA_WIDTH-1:0] data_reg     = 'b0;
reg [18:0]           prescale_reg = 'b0;
reg [3:0]            bit_cnt      = 'b0;

reg wait_idle = 1'b1;   // 复位后等待线路回到空闲态，防止半截数据造成假接收

assign m_axis_tdata  = m_axis_tdata_reg;
assign m_axis_tvalid = m_axis_tvalid_reg;

assign busy          = busy_reg;
assign overrun_error = overrun_error_reg;
assign frame_error   = frame_error_reg;

always @(posedge clk) begin
    if (rst) begin
        m_axis_tdata_reg  <= 'b0;
        m_axis_tvalid_reg <= 1'b0;
        rxd_reg           <= 1'b1;
        prescale_reg      <= 'b0;
        bit_cnt           <= 'b0;
        busy_reg          <= 1'b0;
        overrun_error_reg <= 1'b0;
        frame_error_reg   <= 1'b0;
        wait_idle         <= 1'b1;
    end else begin
        rxd_reg           <= rxd;
        overrun_error_reg <= 1'b0;
        frame_error_reg   <= 1'b0;

        if (m_axis_tvalid && m_axis_tready) begin
            m_axis_tvalid_reg <= 1'b0;
        end

        if (wait_idle) begin
            // 等待线路空闲：rxd 拉高后才允许检测起始位
            if (rxd_reg) begin
                wait_idle <= 1'b0;
            end
        end else begin
            if (prescale_reg > 0) begin
                prescale_reg <= prescale_reg - 1'b1;
            end else if (bit_cnt > 0) begin
                if (bit_cnt > DATA_WIDTH + 1) begin
                    // 起始位阶段
                    if (!rxd_reg) begin
                        bit_cnt      <= bit_cnt - 1'b1;
                        prescale_reg <= (prescale << 3) - 1'b1;
                    end else begin
                        // 起始位无效，丢弃
                        bit_cnt      <= 'b0;
                        prescale_reg <= 'b0;
                    end
                end else if (bit_cnt > 1) begin
                    // 数据位阶段
                    bit_cnt      <= bit_cnt - 1'b1;
                    prescale_reg <= (prescale << 3) - 1'b1;
                    data_reg     <= {rxd_reg, data_reg[DATA_WIDTH-1:1]};
                end else if (bit_cnt == 1) begin
                    // 停止位阶段
                    bit_cnt <= bit_cnt - 1'b1;
                    if (rxd_reg) begin
                        m_axis_tdata_reg  <= data_reg;
                        m_axis_tvalid_reg <= 1'b1;
                        overrun_error_reg <= m_axis_tvalid_reg;
                    end else begin
                        frame_error_reg <= 1'b1;
                    end
                end
            end else begin
                // 空闲，检测起始位
                busy_reg <= 1'b0;
                if (!rxd_reg) begin
                    prescale_reg <= (prescale << 2) - 2;
                    bit_cnt      <= DATA_WIDTH + 2;
                    data_reg     <= 'b0;
                    busy_reg     <= 1'b1;
                end
            end
        end
    end
end

endmodule