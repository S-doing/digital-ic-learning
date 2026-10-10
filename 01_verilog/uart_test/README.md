The UART transmitter and receiver both use a single transmit or receive pin.
The modules take one parameter, DATA_WIDTH, that specifies the width of both
the data bus and the length of the actual data words communicated.  The
default value is 8 for an 8 bit interface.  The prescale input determines the
data rate - it should be set to Fclk / (baud * 8).  This is an input instead
of a parameter so it can be changed at run time, though it is not buffered
internally so care should be used to avoid corrupt data.  The main interface
to the user design is an AXI4-Stream interface that consists of the tdata,
tvalid, and tready signals.  tready flows in the opposite direction.  tdata
is considered valid when tvalid is high.  The destination will accept data
only when tready is high.  Data is transferred from the source to the
destination only when both tvalid and tready are high, otherwise the bus is
stalled.

Both interfaces also present a 'busy' signal that is high when an operation is
taking place.  The receiver also presents overrun error and frame error strobe
outputs.  If the data word currently in the tdata output register is not read
before another word is received, then a single cycle pulse will be emitted
from overrun_error and the word is discarded.  If the receiver does not get a
stop bit of the right level, then a single pulse will be emitted from the
frame_error output and the received word will be discarded.

<!-- UART 发送器和接收器各使用一个引脚进行数据传输或接收。这些模块包含一个名为 `DATA_WIDTH` 的参数，用于指定数据总线的位宽以及实际传输数据字的长度；默认值为 8，对应 8 位接口。`prescale`（预分频）输入决定了数据速率，其值应设置为 `Fclk / (baud * 8)`。该值作为输入信号而非参数提供，以便在运行时进行动态调整；但由于内部未设缓冲机制，更改时需谨慎操作，以避免数据损坏。与用户设计交互的主要接口为 AXI4-Stream 接口，包含 `tdata`、`tvalid` 和 `tready` 信号。其中，`tready` 信号的流向与数据流向相反。当 `tvalid` 为高电平时，`tdata` 上的数据被视为有效；接收端仅在 `tready` 为高电平时接收数据。只有当 `tvalid` 和 `tready` 同时为高电平时，数据才会从源端传输至目的端，否则总线将处于停滞状态。
两个接口均提供一个 `busy`（忙）信号，该信号在执行操作期间保持高电平。接收器还提供溢出错误（overrun error）和帧错误（frame error）的脉冲输出。如果 `tdata` 输出寄存器中的当前数据字未被读取便接收到了新数据字，`overrun_error` 信号将输出一个单周期脉冲，且该数据字会被丢弃。若接收器未检测到电平正确的停止位，`frame_error` 信号将输出一个脉冲，同时丢弃接收到的数据字。 -->