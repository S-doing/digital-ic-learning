# SPI Master 控制器（AXI-Stream 接口）

## 1. 模块简介
本项目实现了一个基于 AXI4-Stream 协议的 SPI Master 发送控制器。
该模块从上游 FIFO 接收 8 位并行数据，通过标准 SPI 协议（Mode 0）将数据串行移出至 MOSI 引脚，同时采样 MISO 引脚数据。
目前版本为了适配 `UART -> FIFO -> SPI` 的单向数据流架构，默认屏蔽了 AXI Master（读出）接口，专注于高速数据发送。

主要特性：
- 支持 SPI Mode 0（CPOL=0, CPHA=0），空闲时 SCLK 为低，上升沿采样，下降沿改变数据
- 串行时钟 SCLK 频率可通过参数 `SCLK_DIV` 自由配置
- 符合 AXI-Stream 握手规范，支持反压
- 自动管理片选信号（CS）建立时间，确保从机正确响应

## 2. 文件结构
| 文件 | 说明 |
|------|------|
| `spi_master.v` | SPI Master 核心逻辑模块 |
| `spi_master_tb.v` | 顶层仿真测试平台（包含 SPI 从机模型） |

## 3. 模块说明

### 3.1 参数

| 参数 | 默认值 | 说明 |
|------|--------|------|
| `RUN_MODE` | 0 | SPI 工作模式，默认 Mode 0 |
| `DATA_WIDTH` | 8 | 传输的数据位宽 |
| `SCLK_DIV` | 8 | SCLK 分频系数，SCLK 频率 = 系统时钟 / SCLK_DIV |

### 3.2 端口

| 端口 | 方向 | 位宽 | 说明 |
|------|------|------|------|
| `clk` | input | 1 | 系统时钟 |
| `rst` | input | 1 | 高电平复位 |
| `s_axis_tdata` | input | `DATA_WIDTH` | AXI 输入数据 |
| `s_axis_tvalid` | input | 1 | AXI 数据有效标志 |
| `s_axis_tready` | output | 1 | AXI 接收就绪（空闲且未满时为 1） |
| `sclk` | output | 1 | SPI 串行时钟 |
| `cs_n` | output | 1 | SPI 片选信号（低电平有效） |
| `mosi` | output | 1 | SPI 主机输出从机输入 |
| `miso` | input | 1 | SPI 主机输入从机输出 |
| `busy` | output | 1 | 忙状态指示，1 表示正在发送数据 |

## 4. 内部结构与工作原理

- **时钟分频机制**：利用 `SCLK_DIV` 和预留最高位的计数器 (`sclk_cnt[SCLK_WIDTH]`)，精准生成 50% 占空比的 SCLK，保证上升沿与下降沿稳定交替。
- **数据移位**：在 SCLK 下降沿将数据推出至 `mosi`，在 SCLK 上升沿采样 `miso` 并存入 `rx_data_reg`。
- **状态控制**：使用 `busy_reg` 取代繁杂的状态机，配合 `tx_bit_cnt` 计数器（初始值设为 8），保证完整的 8 个时钟周期数据收发后，自动拉高 `cs_n` 结束传输。

## 5. AXI-Stream 握手协议
- 数据传输发生在 `s_axis_tvalid && s_axis_tready` 同时为高的时钟上升沿。
- 当模块空闲（`busy == 0`）时，`s_axis_tready` 拉高，表示可以接收新数据。
- 一旦握手成功，`s_axis_tready` 拉低，模块进入发送状态，直到 8 bit 数据发送完毕才重新拉高。

## 6. 仿真验证要点

`spi_master_tb.v` 提供了一个 SPI 从机（Slave）的仿真模型：

| 测试项 | 检查点 |
|--------|--------|
| CS 时序 | `cs_n` 拉低前，`mosi` 必须已放好 bit7；结束后 `cs_n` 拉高 |
| SCLK 时钟 | 刚好产生 8 个方波周期，且占空比接近 50% |
| 模式 0 时序 | 从机在上升沿采到正确的 MOSI 数据，主机在下降沿改变数据 |
| 完整传输 | 从机最终收到的数据与主机发送的数据一致（如 0x55） |

## 7. 已知问题与后续扩展
- **全双工扩展**：当前版本屏蔽了 M 端 AXI 接口。若后续需要读取 SPI 从机数据（如 Flash 读操作），只需取消代码中 `m_axis` 相关端口的注释，并在发送结束时拉高 `m_axis_tvalid` 即可。
- **模式扩展**：参数 `RUN_MODE` 预留了 0~3，但当前代码仅实现了 Mode 0。如需支持其他模式，需要根据 CPOL 和 CPHA 修改 SCLK 初始电平及采样边沿。

## 8. 修改历史
| 日期 | 版本 | 修改内容 | 作者 |
|------|------|---------|------|
| 2026-10-21 | v1.0 | 初始版本，SPI Mode 0 发送控制器，适配 AXI-Stream | [may] |