## 1. Project Overview

This project implements a simple synchronous AXI4-Stream FIFO using Verilog. It is designed to buffer data during UART transmission or reception.

The input and output interfaces share the same clock and use the AXI4-Stream `TVALID` / `TREADY` handshake mechanism to control data transfers.

The current version is intended for learning FIFO read/write control, full/empty detection, and AXI4-Stream handshaking. It also serves as a foundation for future integration with UART TX and UART RX modules.

## 2. Features

- Configurable data width and FIFO depth.
- Synchronous FIFO architecture using a single clock domain.
- Read and write pointers for managing FIFO storage.
- An additional pointer bit to distinguish between full and empty states.
- AXI4-Stream `TVALID` / `TREADY` handshaking for read and write operations.
- Backpressure support: when the downstream receiver is not ready, the FIFO preserves the current valid output data.
- A dedicated Testbench for functional simulation.

## 3. Module Parameters

| Parameter | Default Value | Description |
|---|---:|---|
| `DATA_WIDTH` | 8 | Data width in bits. The default value is 8 bits. |
| `FIFO_DEPTH` | 16 | FIFO storage depth. The default capacity is 16 bytes. |

The current implementation requires `FIFO_DEPTH` to be greater than or equal to 2 and to be a power of two.

## 4. Interface Description

### Clock and Reset

| Signal | Direction | Description |
|---|---|---|
| `clk` | Input | FIFO operating clock |
| `rst` | Input | Active-high synchronous reset |

### AXI4-Stream Input Interface

| Signal | Direction | Description |
|---|---|---|
| `s_axis_tdata` | Input | Input data |
| `s_axis_tvalid` | Input | Indicates that the upstream data is valid |
| `s_axis_tready` | Output | Indicates that the FIFO can accept input data |

When `s_axis_tvalid` and `s_axis_tready` are both high at the same rising edge of the clock, the FIFO accepts one data item and advances the write pointer.

### AXI4-Stream Output Interface

| Signal | Direction | Description |
|---|---|---|
| `m_axis_tdata` | Output | Data currently presented by the FIFO |
| `m_axis_tvalid` | Output | Indicates that valid data is available in the FIFO |
| `m_axis_tready` | Input | Indicates that the downstream receiver is ready to accept data |

When `m_axis_tvalid` and `m_axis_tready` are both high at the same rising edge of the clock, a data transfer is completed and the read pointer advances.

## 5. Core Design Principles

### 5.1 Write Control

The write enable is defined as:

```verilog
wr_en = s_axis_tvalid && s_axis_tready;
```

When the input handshake succeeds, the FIFO writes `s_axis_tdata` to the memory location addressed by the current write pointer and advances the write pointer.

### 5.2 Read Control

The read enable is defined as:

```verilog
rd_en = m_axis_tvalid && m_axis_tready;
```

When the output handshake succeeds, the FIFO advances the read pointer to the next data item.

### 5.3 Full and Empty Detection

- The FIFO is empty when the read pointer and write pointer are equal.
- The FIFO is full when the lower address bits of the pointers are equal but their highest wrap bits are different.

These flags prevent invalid reads from an empty FIFO and writes to a full FIFO.

### 5.4 Backpressure Handling

When `m_axis_tvalid = 1` and `m_axis_tready = 0`, the downstream receiver has not accepted the current data. The FIFO must not advance the read pointer, and the current valid output data must remain stable until the handshake succeeds.

## 6. Simulation and Verification

**Testbench:** `sync_axis_fifo_tb.v`

**Device Under Test (DUT):** `sync_axis_fifo.v`

The current Testbench verifies the following scenarios:

    test1 ： write 1 byte to fifo
    test2 :  Fill the FIFO to capacity
    test3 :  read n byte form fifo
    test4 ： Simultaneously write data to and read data from the FIFO.

### Simulation Steps in Vivado

1. Add `sync_axis_fifo.v` to Design Sources.
2. Add `sync_axis_fifo_tb.v` to Simulation Sources.
3. Set `sync_axis_fifo_tb` as the simulation top module.
4. Run Behavioral Simulation.
5. Check the simulation log and waveforms to confirm that the tests pass.

## 7. Current Limitations

- The current version supports only a synchronous FIFO and does not support data transfer across clock domains.
- Only the basic AXI4-Stream data channel is implemented. Optional signals such as `TLAST`, `TKEEP`, `TSTRB`, and `TUSER` are not implemented.
- Current tests mainly cover single-byte transfers and backpressure. Continuous transfers, full/empty boundary conditions, pointer wraparound, and simultaneous read/write operations require further verification.
- This implementation is intended primarily for RTL learning and functional simulation. System-level UART integration, synthesis report analysis, and comprehensive boundary-condition verification have not yet been completed.