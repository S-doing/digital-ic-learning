`timescale 1ns/1ps

module write_data2fifo #(
    parameter DATA_WIDTH = 32
) (
    input                                clk,
    input                                rst_n,
    input                                write_en,
    input  [DATA_WIDTH*4-1:0]            user_data,

    output [DATA_WIDTH-1:0]              m_axi_awaddr,
    output [7:0]                         m_axi_awlen,     // 实际写入个数 = len + 1
    output [2:0]                         m_axi_awsize,
    output [1:0]                         m_axi_awburst,
    output                               m_axi_awvalid,
    input                                m_axi_awready,                        


    output [DATA_WIDTH-1:0]              m_axi_wdata,
    output [3:0]                         m_axi_wstrb,
    output                               m_axi_wlast,
    output                               m_axi_wvalid,
    input                                m_axi_wready,

    input  [1:0]                         m_axi_bresp,
    input                                m_axi_bvalid,
    output                               m_axi_bready   
);

reg  [DATA_WIDTH-1:0]                    m_axi_awaddr_reg;
reg  [7:0]                               m_axi_awlen_reg;     // 实际写入个数 = len + 1
reg  [2:0]                               m_axi_awsize_reg;
reg  [1:0]                               m_axi_awburst_reg;
reg                                      m_axi_awvalid_reg;
reg  [DATA_WIDTH-1:0]                    m_axi_wdata_reg;
reg  [3:0]                               m_axi_wstrb_reg;
reg                                      m_axi_wlast_reg;
reg                                      m_axi_wvalid_reg;
reg                                      m_axi_bready_reg;  

assign     m_axi_awaddr  = m_axi_awaddr_reg;
assign     m_axi_awlen   = m_axi_awlen_reg;  
assign     m_axi_awsize  = m_axi_awsize_reg;
assign     m_axi_awburst = m_axi_awburst_reg;
assign     m_axi_awvalid = m_axi_awvalid_reg;
assign     m_axi_wdata   = m_axi_wdata_reg;
assign     m_axi_wstrb   = m_axi_wstrb_reg;
assign     m_axi_wlast   = m_axi_wlast_reg;
assign     m_axi_wvalid  = m_axi_wvalid_reg;
assign     m_axi_bready  = m_axi_bready_reg; 


localparam S_IDLE = 3'd0;
localparam S_AW   = 3'd1;
localparam S_W    = 3'd2;
localparam S_B    = 3'd3;
localparam [1:0] OKAY   = 'b0;


reg [2:0]          STATE;  
reg [$clog2(DATA_WIDTH):0]  w_data_cnt;
reg [$clog2(DATA_WIDTH):0]  w_data_cnt_max;  


always @(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
       STATE         <=  S_IDLE;
       m_axi_awvalid_reg <= 'b0;
       m_axi_wvalid_reg  <= 'b0;
       m_axi_bready_reg  <= 'b0;
       w_data_cnt        <= 'b0;
       w_data_cnt_max    <= 'b0; 
    end else begin
       case (STATE)
        S_IDLE:begin
            if(write_en)begin
                m_axi_awaddr_reg   <= 'h0000_0000;           //写入地址
                m_axi_awlen_reg    <= 'b11;                  //写入长度 3+1 
                w_data_cnt_max     <= 'b11;                  //写入长度 3+1 
                m_axi_awsize_reg   <= 'b10;                  //每次4字节
                m_axi_awburst_reg  <= 'b01;                  //递增模式
                m_axi_awvalid_reg  <= 'b1;
                w_data_cnt         <= 'b0;
                STATE              <= S_AW; 
            end else begin
                m_axi_awvalid_reg <= 'b0;
                m_axi_wvalid_reg  <= 'b0;
                m_axi_bready_reg  <= 'b0;            
            end
        end
        S_AW  :begin
            if(m_axi_awready && m_axi_awvalid_reg) begin                      //收到握手信号
                m_axi_awvalid_reg          <= 'b0;      //数据发送成功，valid信号拉低
                m_axi_wdata_reg            <= user_data[w_data_cnt * DATA_WIDTH +: DATA_WIDTH];//需要发送的数据
                m_axi_wstrb_reg            <= 'b1111;   //有效位
                m_axi_wlast_reg            <= (w_data_cnt == w_data_cnt_max) ? 'b1 : 'b0;           
                m_axi_wvalid_reg           <= 'b1;
                w_data_cnt                 <= w_data_cnt + 'b1;
                STATE                      <= S_W;
            end
        end
        S_W   :begin
            if(m_axi_wready && m_axi_wvalid_reg) begin
                // m_axi_wvalid_reg           <= 'b0;
                if(w_data_cnt <= w_data_cnt_max) begin                    
                    m_axi_wdata_reg            <= user_data[w_data_cnt * DATA_WIDTH +: DATA_WIDTH];//需要发送的数据
                    m_axi_wstrb_reg            <= 'b1111;   //有效位
                    m_axi_wlast_reg            <= (w_data_cnt == w_data_cnt_max) ? 'b1 : 'b0;         
                    m_axi_wvalid_reg           <= 'b1;
                    w_data_cnt                 <= w_data_cnt + 'b1;
                end else begin
                    m_axi_wvalid_reg           <= 'b0;//需要发送的数据
                    m_axi_wstrb_reg            <= 'b0000;   //有效位
                    m_axi_wlast_reg            <= 'b0;
                    m_axi_bready_reg           <= 'b1;     //开始接收反馈         
                    STATE                      <= S_B;                  
                end
            end
        end
        S_B   :begin
            if(m_axi_bvalid && m_axi_bready_reg) begin
                if(m_axi_bresp == OKAY) begin
                    m_axi_bready_reg               <= 'b0;
                    STATE                          <= S_IDLE;                    
                end
            end
        end 
        default:begin
            STATE <= S_IDLE;
        end 
       endcase 
    end
end









fifo_generator_0 fifo_generator_0_u (
    .s_aclk(clk),
    .s_aresetn(rst_n),          // 注意：AXI IP 默认是低电平复位！
    
    // ===== 地址通道 =====
    .s_axi_awid     (8'b0),           
    .s_axi_awaddr   (m_axi_awaddr),
    .s_axi_awlen    (m_axi_awlen),
    .s_axi_awsize   (m_axi_awsize),
    .s_axi_awburst  (m_axi_awburst),
    .s_axi_awlock   (1'b0),           
    .s_axi_awcache  (4'b0000),        
    .s_axi_awprot   (3'b000),         
    .s_axi_awqos    (4'b0000),        
    .s_axi_awregion (4'b0000),        
    .s_axi_awvalid  (m_axi_awvalid),
    .s_axi_awready  (m_axi_awready),

    // ===== 数据通道 =====
    .s_axi_wdata    (m_axi_wdata),
    .s_axi_wstrb    (m_axi_wstrb),
    .s_axi_wlast    (m_axi_wlast),
    .s_axi_wvalid   (m_axi_wvalid),
    .s_axi_wready   (m_axi_wready),

    // ===== 响应通道 =====
    // .s_axi_bid   (bid_wire),       // 输出，不用就悬空
    .s_axi_bresp    (m_axi_bresp),
    .s_axi_bvalid   (m_axi_bvalid),
    .s_axi_bready   (m_axi_bready)

    


);



endmodule

// `timescale 1ns/1ps

// module write_data2fifo #(
//     parameter DATA_WIDTH = 32
// ) (
//     input                                clk,
//     input                                rst_n,
//     input                                write_en,
//     input  [DATA_WIDTH*4-1:0]            user_data,

//     output [DATA_WIDTH-1:0]              m_axi_awaddr,
//     output [7:0]                         m_axi_awlen,     // 实际写入个数 = len + 1
//     output [2:0]                         m_axi_awsize,
//     output [1:0]                         m_axi_awburst,
//     output                               m_axi_awvalid,
//     input                                m_axi_awready,                        

//     output [DATA_WIDTH-1:0]              m_axi_wdata,
//     output [3:0]                         m_axi_wstrb,
//     output                               m_axi_wlast,
//     output                               m_axi_wvalid,
//     input                                m_axi_wready,

//     input  [1:0]                         m_axi_bresp,
//     input                                m_axi_bvalid,
//     output                               m_axi_bready   
// );

// reg  [DATA_WIDTH-1:0]                    m_axi_awaddr_reg;
// reg  [7:0]                               m_axi_awlen_reg;
// reg  [2:0]                               m_axi_awsize_reg;
// reg  [1:0]                               m_axi_awburst_reg;
// reg                                      m_axi_awvalid_reg;
// reg  [DATA_WIDTH-1:0]                    m_axi_wdata_reg;
// reg  [3:0]                               m_axi_wstrb_reg;
// reg                                      m_axi_wlast_reg;
// reg                                      m_axi_wvalid_reg;
// reg                                      m_axi_bready_reg;  

// assign     m_axi_awaddr  = m_axi_awaddr_reg;
// assign     m_axi_awlen   = m_axi_awlen_reg;  
// assign     m_axi_awsize  = m_axi_awsize_reg;
// assign     m_axi_awburst = m_axi_awburst_reg;
// assign     m_axi_awvalid = m_axi_awvalid_reg;
// assign     m_axi_wdata   = m_axi_wdata_reg;
// assign     m_axi_wstrb   = m_axi_wstrb_reg;
// assign     m_axi_wlast   = m_axi_wlast_reg;
// assign     m_axi_wvalid  = m_axi_wvalid_reg;
// assign     m_axi_bready  = m_axi_bready_reg; 

// localparam S_IDLE = 3'd0;
// localparam S_AW   = 3'd1;
// localparam S_W    = 3'd2;
// localparam S_B    = 3'd3;
// localparam [1:0] OKAY   = 2'b0;

// reg [2:0]  STATE;  
// reg [3:0]  w_data_cnt;       // 放宽一点位宽
// reg [3:0]  w_data_cnt_max;  

// always @(posedge clk or negedge rst_n) begin
//     if(!rst_n)begin
//        STATE              <= S_IDLE;
//        m_axi_awvalid_reg  <= 1'b0;
//        m_axi_wvalid_reg   <= 1'b0;
//        m_axi_bready_reg   <= 1'b0;
//        m_axi_wlast_reg    <= 1'b0;
//        w_data_cnt         <= 4'd0;
//        w_data_cnt_max     <= 4'd0; 
//        m_axi_wdata_reg    <= 32'd0;
//        m_axi_awaddr_reg   <= 32'd0;
//     end else begin
//        case (STATE)
//         S_IDLE:begin
//             if(write_en)begin
//                 m_axi_awaddr_reg   <= 32'h0000_0000;           
//                 m_axi_awlen_reg    <= 8'd3;                  // 3+1 = 4个数据
//                 w_data_cnt_max     <= 4'd3;                  
//                 m_axi_awsize_reg   <= 3'b010;                  
//                 m_axi_awburst_reg  <= 2'b01;                  
//                 m_axi_awvalid_reg  <= 1'b1;
//                 w_data_cnt         <= 4'd0;
//                 STATE              <= S_AW; 
//             end else begin
//                 m_axi_awvalid_reg <= 1'b0;
//                 m_axi_wvalid_reg  <= 1'b0;
//                 m_axi_bready_reg  <= 1'b0;            
//             end
//         end
        
//         S_AW  :begin
//             if(m_axi_awready && m_axi_awvalid_reg) begin                      
//                 m_axi_awvalid_reg <= 1'b0;      
//                 m_axi_wdata_reg   <= user_data[0 +: DATA_WIDTH]; 
//                 m_axi_wstrb_reg   <= 4'b1111;   
//                 m_axi_wlast_reg   <= 1'b0;           
//                 m_axi_wvalid_reg  <= 1'b1;
//                 w_data_cnt        <= 4'd1;
//                 STATE             <= S_W;
//             end
//         end
        
//         S_W   :begin
//             if(m_axi_wready && m_axi_wvalid_reg) begin
//                 if(w_data_cnt <= w_data_cnt_max) begin                    
//                     m_axi_wdata_reg  <= user_data[w_data_cnt * DATA_WIDTH +: DATA_WIDTH];
//                     m_axi_wstrb_reg  <= 4'b1111;   
//                     m_axi_wlast_reg  <= (w_data_cnt == w_data_cnt_max) ? 1'b1 : 1'b0;         
//                     m_axi_wvalid_reg <= 1'b1;
//                     w_data_cnt       <= w_data_cnt + 1'b1;
//                 end else begin
//                     m_axi_wvalid_reg <= 1'b0;
//                     m_axi_wstrb_reg  <= 4'b0000;
//                     m_axi_wlast_reg  <= 1'b0;
//                     m_axi_bready_reg <= 1'b1;          
//                     STATE            <= S_B;                  
//                 end
//             end
//         end
        
//         S_B   :begin
//             if(m_axi_bvalid && m_axi_bready_reg) begin
//                 if(m_axi_bresp == OKAY) begin
//                     m_axi_bready_reg <= 1'b0;
//                     STATE            <= S_IDLE;                    
//                 end
//             end
//         end 
//         default: STATE <= S_IDLE;
//        endcase 
//     end
// end

//     // ==========================================
//     // 解决 bvalid 不拉高的终极操作：
//     // 把 M_AXI 侧（内部下游）全部强行绑死，骗过内部状态机！
//     // ==========================================
    
//     // 先把悬空或接收用的 wire 声明好
//     wire        wr_rst_busy;
//     wire        rd_rst_busy;
//     wire [7:0]  s_axi_bid;
//     wire        axi_aw_overflow, axi_aw_underflow;
//     wire        axi_w_overflow,  axi_w_underflow;
//     wire        axi_b_overflow,  axi_b_underflow;

//     fifo_generator_0 fifo_generator_0_u (
//         .wr_rst_busy(wr_rst_busy),            
//         .rd_rst_busy(rd_rst_busy),            
//         .s_aclk(clk),                      
//         .s_aresetn(rst_n),                
        
//         // ===== 1. S_AXI (主控写入端，照常连) =====
//         .s_axi_awid     (8'b0),              
//         .s_axi_awaddr   (m_axi_awaddr),          
//         .s_axi_awlen    (m_axi_awlen),            
//         .s_axi_awsize   (m_axi_awsize),          
//         .s_axi_awburst  (m_axi_awburst),        
//         .s_axi_awlock   (1'b0),          
//         .s_axi_awcache  (4'b0000),        
//         .s_axi_awprot   (3'b000),          
//         .s_axi_awqos    (4'b0000),            
//         .s_axi_awregion (4'b0000),      
//         .s_axi_awvalid  (m_axi_awvalid),        
//         .s_axi_awready  (m_axi_awready),        
        
//         .s_axi_wdata    (m_axi_wdata),            
//         .s_axi_wstrb    (m_axi_wstrb),            
//         .s_axi_wlast    (m_axi_wlast),            
//         .s_axi_wvalid   (m_axi_wvalid),          
//         .s_axi_wready   (m_axi_wready),          
        
//         .s_axi_bid      (s_axi_bid),                
//         .s_axi_bresp    (m_axi_bresp),            
//         .s_axi_bvalid   (m_axi_bvalid),          
//         .s_axi_bready   (m_axi_bready),          
        
//         // ===== 2. M_AXI (内部读出端，强行绑死造假) =====
//         // 所有输出引脚全部留空
//         .m_axi_awid     (),
//         .m_axi_awaddr   (),
//         .m_axi_awlen    (),
//         .m_axi_awsize   (),
//         .m_axi_awburst  (),
//         .m_axi_awlock   (),
//         .m_axi_awcache  (),
//         .m_axi_awprot   (),
//         .m_axi_awqos    (),
//         .m_axi_awregion (),
//         .m_axi_awvalid  (),
//         .m_axi_wdata    (),
//         .m_axi_wstrb    (),
//         .m_axi_wlast    (),
//         .m_axi_wvalid   (),
//         .m_axi_bready   (),

//         // 👇【核心大招】：输入引脚全部给固定值，告诉内部下游永远畅通！
//         .m_axi_awready  (1'b1),     
//         .m_axi_wready   (1'b1),      
//         .m_axi_bid      (8'd0),         
//         .m_axi_bresp    (2'b00),      
//         .m_axi_bvalid   (1'b1),      // 强制拉高，告诉内部写成功
        
//         // ===== 3. 状态溢出引脚（留空） =====
//         .axi_aw_overflow(axi_aw_overflow),    
//         .axi_aw_underflow(axi_aw_underflow),  
//         .axi_w_overflow(axi_w_overflow),      
//         .axi_w_underflow(axi_w_underflow),    
//         .axi_b_overflow(axi_b_overflow),      
//         .axi_b_underflow(axi_b_underflow)    
//     );

// endmodule