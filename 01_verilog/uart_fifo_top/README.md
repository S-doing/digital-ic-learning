# UART FIFO 回环系统（AXI-Stream 接口）

## 1. 项目简介
本项目实现了一个基于 AXI-Stream 协议的 UART 回环系统。
外部串口数据通过 `rxd` 进入 FPGA，经 UART_RX 解码为 8 位并行数据，
通过 AXI-Stream 写入同步 FIFO 缓存，再由 UART_TX 从 FIFO 读出并
通过 `txd` 发回外部串口。

主要特性：
- 支持 8 位数据位、1 位停止位、无校验
- 波特率可通过 `prescale` 配置（默认 9600 @ 50MHz）
- AXI-Stream 接口，支持反压（tready/tvalid 握手）
- 同步 FIFO 深度可参数化（默认 16）

## 2. 文件结构
| 文件 | 说明 |
|------|------|
| `uart_fifo_top.v` | 顶层模块，连接 RX、FIFO、TX |
| `uart_rx.v` | UART 接收模块，输出 AXI-Stream |
| `uart_tx.v` | UART 发送模块，输入 AXI-Stream |
| `sync_axis_fifo.v` | 同步 AXI-Stream FIFO |
| `uart_fifo_top_tb.v` | 顶层仿真测试平台 |
| `doc/` | 波形截图、时序图（可选） |

## 3. 模块说明

### 3.1 uart_fifo_top
顶层模块，无参数。

| 端口 | 方向 | 位宽 | 说明 |
|------|------|------|------|
| clk | input | 1 | 系统时钟（默认 50MHz） |
| rst | input | 1 | 高电平复位 |
| prescale | input | 16 | 波特率分频系数，`prescale = clk_freq / baud / 8` |
| rxd | input | 1 | UART 接收引脚 |
| txd | output | 1 | UART 发送引脚 |

### 3.2 uart_rx
| 参数 | 默认值 | 说明 |
|------|--------|------|
| DATA_WIDTH | 8 | 数据位宽 |

| 端口 | 方向 | 位宽 | 说明 |
|------|------|------|------|
| clk | input | 1 | 时钟 |
| rst | input | 1 | 复位（高有效） |
| rxd | input | 1 | UART 输入 |
| prescale | input | 16 | 波特率分频 |
| m_axis_tdata | output | 8 | AXI 输出数据 |
| m_axis_tvalid | output | 1 | 数据有效 |
| m_axis_tready | input | 1 | 接收就绪 |
| busy | output | 1 | 正在接收 |
| overrun_error | output | 1 | 溢出错误 |
| frame_error | output | 1 | 帧错误 |

### 3.3 uart_tx
（类似表格，这里省略，请自行补充）

### 3.4 sync_axis_fifo
| 参数 | 默认值 | 说明 |
|------|--------|------|
| DATA_WIDTH | 8 | 数据位宽 |
| FIFO_DEPTH | 16 | FIFO 深度（必须为 2 的幂） |

| 端口 | 方向 | 说明 |
|------|------|------|
| clk / rst | input | 时钟/复位 |
| s_axis_tdata / tvalid / tready | input/output | 写端 AXI-Stream |
| m_axis_tdata / tvalid / tready | output/input | 读端 AXI-Stream |

## 4. AXI-Stream 握手协议
- 数据传输发生在 `tvalid && tready` 同时为高的时钟上升沿。
- `tvalid` 由主机驱动，表示数据有效。
- `tready` 由从机驱动，表示可以接收。
- 若 `tready=0`，主机必须保持 `tvalid=1` 且数据不变，直到握手成功。

## 7. 已知问题与限制
- 当前不支持奇偶校验。
- FIFO 深度固定为 16，可参数化修改。
- 若 `prescale` 配置错误，波特率会不匹配。

## 8. 修改历史
| 日期 | 版本 | 修改内容 | 作者 |
|------|------|---------|------|
| 2026-10-14 | v1.0 | 初始版本 | may|