// Intel 8250 serial port (UART).
// 中文注释：实现 8250 兼容串口驱动，负责与外部终端通信，是最小系统输出
// "Hello OS" 等调试信息的关键外设。

#include "types.h"
#include "defs.h"
#include "param.h"
#include "traps.h"
#include "spinlock.h"
#include "sleeplock.h"
#include "fs.h"
#include "file.h"
#include "mmu.h"
#include "proc.h"
#include "x86.h"

#define COM1    0x3f8

static int uart;    // is there a uart?
// 中文注释：uart 作为标志位，表示硬件是否存在且已初始化，避免在无串口时
// 继续访问寄存器导致异常。

void
uartinit(void)
{
  char *p;

  // Turn off the FIFO
  outb(COM1+2, 0);
  // 中文注释：8250 兼容 UART 在初始化阶段先关闭 FIFO，保持最简单的工作模式，
  // 便于理解和调试最小系统的输出流程。

  // 9600 baud, 8 data bits, 1 stop bit, parity off.
  outb(COM1+3, 0x80);    // Unlock divisor
  // 中文注释：设置 LCR (Line Control Register) 的 DLAB 位，允许访问除数寄存器，
  // 从而配置串口波特率。
  outb(COM1+0, 115200/9600);
  // 中文注释：写入波特率除数低位，将串口速率配置为 9600bps。此配置与最小
  // 裸机输出实验一致，可在 QEMU 默认终端中正常显示字符。
  outb(COM1+1, 0);
  outb(COM1+3, 0x03);    // Lock divisor, 8 data bits.
  // 中文注释：清除 DLAB 并设置数据格式为 8 位数据、1 位停止位、无校验，满足
  // 常见终端的串行通信要求。
  outb(COM1+4, 0);
  outb(COM1+1, 0x01);    // Enable receive interrupts.
  // 中文注释：开启接收中断，允许内核在收到字符时唤醒 console 驱动，尽管最小
  // 裸机实验可不使用中断，但 xv6 完整内核需要响应串口输入。

  // If status is 0xFF, no serial port.
  if(inb(COM1+5) == 0xFF)
    return;
  uart = 1;
  // 中文注释：如果读取状态寄存器得到 0xFF，说明串口不存在；否则标记初始化成功。

  // Acknowledge pre-existing interrupt conditions;
  // enable interrupts.
  inb(COM1+2);
  inb(COM1+0);
  ioapicenable(IRQ_COM1, 0);

  // Announce that we're here.
  for(p="xv6...\n"; *p; p++)
    uartputc(*p);
  // 中文注释：启动完成后通过串口打印 "xv6..."，验证输出路径工作正常。实验中
  // 可以修改为打印 "Hello OS"，与任务目标呼应。
}

void
uartputc(int c)
{
  int i;

  if(!uart)
    return;
  // 中文注释：未检测到串口时直接返回，避免访问无效 I/O 端口。
  for(i = 0; i < 128 && !(inb(COM1+5) & 0x20); i++)
    microdelay(10);
  // 中文注释：循环等待 LSR 中的 THRE 位置 1，表示发送缓冲空闲；每次轮询之间
  // 调用 microdelay 减少总线压力，确保字符按顺序发送。
  outb(COM1+0, c);
  // 中文注释：最终把要发送的字符写入 THR 寄存器，即可由硬件串行发送到终端。
}

static int
uartgetc(void)
{
  if(!uart)
    return -1;
  if(!(inb(COM1+5) & 0x01))
    return -1;
  return inb(COM1+0);
}

void
uartintr(void)
{
  consoleintr(uartgetc);
}
