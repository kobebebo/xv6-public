/* Simple linker script for the JOS kernel.
   See the GNU ld 'info' manual ("info ld") to learn the syntax. */

OUTPUT_FORMAT("elf32-i386", "elf32-i386", "elf32-i386")
OUTPUT_ARCH(i386)
ENTRY(_start)
/* 中文注释：指定生成的内核镜像为 32 位 i386 ELF，并声明入口符号 _start，
 * 这样引导程序在加载完成后会跳入 entry.S 中的 _start 标签。*/

SECTIONS
{
        /* Link the kernel at this address: "." means the current address */
        /* Must be equal to KERNLINK */
        . = 0x80100000;
        /* 中文注释：把链接地址固定为 0x80100000，对应内核在高地址的映射；
         * 实际加载仍在物理地址 0x00100000，通过页表重定位到该高地址上。*/

        .text : AT(0x100000) {
                *(.text .stub .text.* .gnu.linkonce.t.*)
        }
        /* 中文注释：text 段的虚拟地址继承当前地址，但通过 AT 指令指定其物理
         * 加载地址为 0x100000（1MB），与引导加载器约定一致，便于在未开启分页
         * 的阶段顺利执行。*/

	PROVIDE(etext = .);	/* Define the 'etext' symbol to this value */

        /* 中文注释：etext 记录文本段的结束虚拟地址，供内核初始化和调试使用。*/
	.rodata : {
		*(.rodata .rodata.* .gnu.linkonce.r.*)
	}

        /* 中文注释：只读数据段承载常量字符串等内容，通过页表属性保证不可写。*/

	/* Include debugging information in kernel memory */
	.stab : {
		PROVIDE(__STAB_BEGIN__ = .);
		*(.stab);
		PROVIDE(__STAB_END__ = .);
	}

        /* 中文注释：.stab 区段保存调试符号，内核保留它们以便 GDB 或 panic 输出时解析地址。*/

	.stabstr : {
		PROVIDE(__STABSTR_BEGIN__ = .);
		*(.stabstr);
		PROVIDE(__STABSTR_END__ = .);
	}

        /* 中文注释：.stabstr 段保存调试字符串，与 .stab 配合提供符号名称。*/

	/* Adjust the address for the data segment to the next page */
	. = ALIGN(0x1000);

        /* 中文注释：对齐到 4KB 边界，保证数据段和 BSS 段从整页开始，便于页表映射。*/

	/* Conventionally, Unix linkers provide pseudo-symbols
	 * etext, edata, and end, at the end of the text, data, and bss.
	 * For the kernel mapping, we need the address at the beginning
	 * of the data section, but that's not one of the conventional
	 * symbols, because the convention started before there was a
	 * read-only rodata section between text and data. */
	PROVIDE(data = .);
        /* 中文注释：记录数据段起始地址，方便在内核中引用。*/

	/* The data segment */
	.data : {
		*(.data)
	}

	PROVIDE(edata = .);
        /* 中文注释：edata 指向数据段结束、BSS 开始的位置，启动代码据此清零。*/

	.bss : {
		*(.bss)
	}
        /* 中文注释：BSS 段用于未初始化的全局变量，运行时需要被清零。*/

	PROVIDE(end = .);
        /* 中文注释：end 表示内核镜像的末尾，常作为内核堆或物理内存分配的起点。*/

	/DISCARD/ : {
		*(.eh_frame .note.GNU-stack)
	}
}
