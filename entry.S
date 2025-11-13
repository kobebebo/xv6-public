# The xv6 kernel starts executing in this file. This file is linked with
# the kernel C code, so it can refer to kernel symbols such as main().
# The boot block (bootasm.S and bootmain.c) jumps to entry below.
#
# 中文注释：xv6 内核会从本文件的 entry 标签开始执行。由于此文件与
# C 语言内核代码一起链接，因此可以直接引用 main() 等内核符号。前期
# 的引导代码（bootasm.S 与 bootmain.c）会在准备好基础执行环境后跳转
# 到这里继续执行真正的内核启动流程。
        
# Multiboot header, for multiboot boot loaders like GNU Grub.
# http://www.gnu.org/software/grub/manual/multiboot/multiboot.html
#
# Using GRUB 2, you can boot xv6 from a file stored in a
# Linux file system by copying kernel or kernelmemfs to /boot
# and then adding this menu entry:
#
# menuentry "xv6" {
# 	insmod ext2
# 	set root='(hd0,msdos1)'
# 	set kernel='/boot/kernel'
# 	echo "Loading ${kernel}..."
# 	multiboot ${kernel} ${kernel}
# 	boot
# }

#include "asm.h"
#include "memlayout.h"
#include "mmu.h"
#include "param.h"

# Multiboot header.  Data to direct multiboot loader.
.p2align 2
.text
.globl multiboot_header
multiboot_header:
  #define magic 0x1badb002
  #define flags 0
  .long magic
  .long flags
  .long (-magic-flags)

# By convention, the _start symbol specifies the ELF entry point.
# Since we haven't set up virtual memory yet, our entry point is
# the physical address of 'entry'.
#
# 中文注释：按照 ELF 规范，_start 符号会被用作可执行文件的入口地址。
# 在开启分页之前，CPU 仍然使用物理地址执行指令，因此这里把 _start
# 映射到 entry 的物理地址，确保处理器从真实的物理入口继续执行。
.globl _start
_start = V2P_WO(entry)

# Entering xv6 on boot processor, with paging off.
.globl entry
entry:
  # Turn on page size extension for 4Mbyte pages
  movl    %cr4, %eax
  orl     $(CR4_PSE), %eax
  movl    %eax, %cr4
  # 中文注释：首先通过设置 CR4 寄存器打开 PSE（Page Size Extension），
  # 使得后续能够使用 4MB 大页进行分页映射。这样可以用极少的页目录
  # 条目映射整个内核，降低初始化复杂度。
  # Set page directory
  movl    $(V2P_WO(entrypgdir)), %eax
  movl    %eax, %cr3
  # 中文注释：接着把入口页目录 entrypgdir 的物理地址写入 CR3，CPU
  # 会从这个页目录开始进行地址转换，这是进入分页模式前的关键准备。
  # Turn on paging.
  movl    %cr0, %eax
  orl     $(CR0_PG|CR0_WP), %eax
  movl    %eax, %cr0
  # 中文注释：将 CR0 中的 PG（分页）和 WP（写保护）位置 1，正式开启
  # 分页模式。自此以后，CPU 会按照页表把虚拟地址映射到物理地址。

  # Set up the stack pointer.
  movl $(stack + KSTACKSIZE), %esp
  # 中文注释：为 C 代码准备执行栈。栈顶被放置在 stack 数组末尾
  # (stack + KSTACKSIZE)，因为 x86 栈向低地址增长。若没有可用的栈，
  # 后续函数调用、局部变量分配都无法进行，这是进入 C 世界的前提。

  # Jump to main(), and switch to executing at
  # high addresses. The indirect call is needed because
  # the assembler produces a PC-relative instruction
  # for a direct jump.
  mov $main, %eax
  jmp *%eax
  # 中文注释：把 main() 的虚拟地址放入 EAX，再通过间接跳转进入 C 语言
  # 编写的内核主函数。使用间接跳转是为了避免汇编器生成 PC 相对地址，
  # 使我们能够在开启高地址映射后顺利地跳入内核。

.comm stack, KSTACKSIZE
