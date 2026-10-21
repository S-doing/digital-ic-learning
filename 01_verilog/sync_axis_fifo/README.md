# 同步 AXI4-Stream FIFO（sync_axis_fifo）

## 1. 模块简介
本项目实现了一个基于 AXI4-Stream 协议的**同步 FIFO（单时钟域）**。
写端与读端共用同一个 `clk`，通过标准的 `tvalid/tready` 握手完成数据的写入与读出。
内部采用“多一位指针”的设计（最高位作为翻转位），完美区分了 FIFO 的空（Empty）与满（Full）状态，无需额外计数器。

主要特性：
- 单时钟域，读写共用 `clk` 和 `rst`
- AXI4-Stream 接口，支持标准反压（tvalid/tready 握手）
- 数据位宽与 FIFO 深度完全参数化
- 极简的纯组合逻辑空满判断与 AXI 握手信号生成

## 2. 文件结构
| 文件 | 说明 |
|------|------|
| `sync_axis_fifo.v` | 同步 AXI-Stream FIFO 核心模块 |
| `sync_axis_fifo_tb.v` | 仿真测试平台（包含写入、填满、读出、双工读写测试） |

## 3. 模块说明

### 3.1 参数

| 参数 | 默认值 | 说明 |
|------|--------|------|
| `DATA_WIDTH` | 8 | 每个数据字的位宽 |
| `FIFO_DEPTH` | 16 | FIFO 深度（必须为 ≥ 2 的 2 的整数次幂） |
| `PTR_WIDTH` | 自动 | `$clog2(FIFO_DEPTH)`，指针位宽 |

### 3.2 端口

| 端口 | 方向 | 位宽 | 说明 |
|------|------|------|------|
| `clk` | input | 1 | 系统时钟，读写共用 |
| `rst` | input | 1 | 复位，**高电平有效** |
| `s_axis_tdata`  | input  | `DATA_WIDTH` | 写端数据 |
| `s_axis_tvalid` | input  | 1 | 写端数据有效 |
| `s_axis_tready` | output | 1 | 写端就绪（= 非满） |
| `m_axis_tdata`  | output | `DATA_WIDTH` | 读端数据 |
| `m_axis_tvalid` | output | 1 | 读端数据有效（= 非空） |
| `m_axis_tready` | input  | 1 | 读端就绪 |

## 4. 内部结构与工作原理

- **存储体**：`reg [DATA_WIDTH-1:0] ram_fifo [0:FIFO_DEPTH-1]`，双端口读写。
- **读写指针**：`reg [PTR_WIDTH:0] wr_ptr, rd_ptr`。指针位宽比地址位宽多 1 位，最高位为“翻转位（Wrap Bit）”。
- **空满判断**：
  - `空（Empty）`：读写指针完全相等（`wr_ptr == rd_ptr`）。
  - `满（Full）`：读写指针低 `PTR_WIDTH` 位相等，但最高位相反。
- **读取延迟**：纯组合逻辑读（Read Combinational）。当 `m_axis_tvalid && m_axis_tready` 握手成功时，读指针在下个时钟沿递增，但数据（`m_axis_tdata`）是直接从 RAM 吐出的，**没有一拍延迟**。

## 5. AXI-Stream 握手协议
- **写握手**：`s_axis_tvalid && s_axis_tready`。只有 FIFO 未满时（`s_axis_tready=1`），写操作才会发生。
- **读握手**：`m_axis_tvalid && m_axis_tready`。只有 FIFO 非空时（`m_axis_tvalid=1`），读操作才会发生。
- 若接收端未准备好（`tready=0`），发送端的 `tvalid` 必须保持高电平且数据保持不变，直到握手成功。

## 6. 仿真验证说明

`sync_axis_fifo_tb.v` 包含 4 个严格的递进测试项：

| 测试项 | 检查点 |
|--------|--------|
| **Test 1**：单字节写入 | 验证基本的握手写入，`wr_ptr` 从 0 变为 1 |
| **Test 2**：填满 FIFO | 连续写入 16 个数据，检查 `s_axis_tready` 是否在第 16 个数据后拉低，且 `fifo_wr_full` 内部逻辑生效 |
| **Test 3**：连续读出 | 拉高 `m_axis_tready` 连续读取指定数量数据，检查读指针 `rd_ptr` 是否正常递增 |
| **Test 4**：全双工同时读写 | 同时拉高写使能与读使能，验证读写指针独立递增，数据不丢失、不冲突 |

**预期结果**：
- 在 Test 2 写满后，`s_axis_tready` 会立刻变低（防止溢出覆盖）。
- 在 Test 3 读空后，`m_axis_tvalid` 会立刻变低（防止读出无效数据）。

## 7. 已知问题与扩展限制
- **仅支持同步时钟**：读写必须共用 `clk`。若需跨时钟域传输（如 UART 到高速 SPI），需替换为**异步 FIFO**。
- **深度限制**：`FIFO_DEPTH` 必须为 2 的幂，否则空满指针判断逻辑会出错。
- **RAM 未初始化**：由于综合工具会推断为 BRAM/LUTRAM，仿真时未写入的地址默认为 `X`（不定态），需确保 `tvalid` 信号严格控制在非空时有效。
- **无读写冲突保护**：在同一时钟周期对同一地址进行读写时，读出的是旧值（Read-before-write 行为）。

## 8. 修改历史
| 日期 | 版本 | 修改内容 | 作者 |
|------|------|---------|------|
| 2026-10-21 | v1.0 | 初始版本，同步 AXI-Stream FIFO 及完整激励测试 | [may] |