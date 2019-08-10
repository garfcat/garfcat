---
title: "golang 启动过程"
date: 2019-06-20T22:51:54+08:00
draft: true
---

知其然，也要知其所以然，从今天开始研究golang的底层实现，首先从其启动开始；

### 找到启动点
##### 1. 写一个hello world.  
```golang
package main

import (
	"fmt"
)

func main() {
	fmt.Println("hello world")
}
``` 
##### 2.编译后使用gdb找到entry point
```bash
$ gdb hello
 .....
        file type mach-o-x86-64.
	Entry point: 0x1052720
	0x0000000001001000 - 0x0000000001093074 is .text
	0x0000000001093080 - 0x00000000010e19cd is __TEXT.__rodata
	0x00000000010e19e0 - 0x00000000010e1ae2 is __TEXT.__symbol_stub1
	0x00000000010e1b00 - 0x00000000010e2764 is __TEXT.__typelink
	0x00000000010e2768 - 0x00000000010e27d0 is __TEXT.__itablink
	0x00000000010e27d0 - 0x00000000010e27d0 is __TEXT.__gosymtab
	0x00000000010e27e0 - 0x000000000115c6ff is __TEXT.__gopclntab
	0x000000000115d000 - 0x000000000115d158 is __DATA.__nl_symbol_ptr
	0x000000000115d160 - 0x0000000001169c9c is __DATA.__noptrdata
	0x0000000001169ca0 - 0x0000000001170610 is .data
	0x0000000001170620 - 0x000000000118be50 is .bss
	0x000000000118be60 - 0x000000000118e418 is __DATA.__noptrbss
(gdb) info symbol 0x1052720
_rt0_amd64_darwin in section .text
(gdb)
```
可以从entry point 找到入口函数 _rt0_amd64_darwin，可以在源码中搜索一下函数名称,定位函数位置
runtime/rt0_darwin_amd64.s:7，具体如下所示
```bash
TEXT _rt0_amd64_darwin(SB),NOSPLIT,$-8
	JMP	_rt0_amd64(SB)
```
该函数跳转到 _rt0_amd64, _rt0_amd64是一段针对amd64系统的公共启动代码。
```bash
TEXT _rt0_amd64(SB),NOSPLIT,$-8
	MOVQ	0(SP), DI	// argc
	LEAQ	8(SP), SI	// argv
	JMP	runtime·rt0_go(SB)
```
其中 MOVQ 用来操作数据，而LEAQ 用来操作地址，所以
MOVQ	0(SP), DI 是将argc 放到DI寄存器  
LEAQ	8(SP), SI 是将 argv 的地址放到SI寄存器 
然后跳转到runtime·rt0_go(SB）(go1.12.5/src/runtime/asm_amd64.s:87)
```asm
TEXT runtime·rt0_go(SB),NOSPLIT,$0
	// copy arguments forward on an even stack
	MOVQ	DI, AX		// argc
	MOVQ	SI, BX		// argv
	SUBQ	$(4*8+7), SP		// 2args 2auto
	ANDQ	$~15, SP
	MOVQ	AX, 16(SP)
	MOVQ	BX, 24(SP)
```

接下来的流程用下图表示:
![没有参数没有本地变量](https://raw.githubusercontent.com/garfcat/garfcat/master/static/fpspnoargs.png)