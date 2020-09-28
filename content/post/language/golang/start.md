---
title: "通过 hello world 寻找 golang 启动过程"
date: 2019-06-20T22:51:54+08:00
draft: false
tags: [ "go", "start" ]
series: ["golang"]
categories: ["编程语言"]
---

知其然，也要知其所以然，从今天开始研究一下golang的底层实现，首先从其启动开始；

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

接下来的流程用下图表示:
![初始化流程](https://raw.githubusercontent.com/garfcat/garfcat/master/static/start.png)


##### 参数设置
```asm
TEXT runtime·rt0_go(SB),NOSPLIT,$0
	// copy arguments forward on an even stack
	／／将argc 和 argv 复制到指定寄存器中
	MOVQ	DI, AX		// argc
	MOVQ	SI, BX		// argv
	SUBQ	$(4*8+7), SP		// 2args 2auto
	// sp 16 字节对齐
	ANDQ	$~15, SP
	// 将 argc 复制到 sp+16 , argv 复制到 sp+24 
	MOVQ	AX, 16(SP)
	MOVQ	BX, 24(SP)
```

##### g0 初始化

```asm
	// create istack out of the given (operating system) stack.
	// _cgo_init may update stackguard.
	// g0 定义在 go1.12.5/src/runtime/proc.go:81
    // g0.stackguard0 =  rsp-64*1024+104
    // g0.stackguard1 = g0.stackguard0
    // g0.stack.lo = g0.stackguard0
    // g0.stack.hi = rsp 
	MOVQ	$runtime·g0(SB), DI
	LEAQ	(-64*1024+104)(SP), BX
	MOVQ	BX, g_stackguard0(DI)
	MOVQ	BX, g_stackguard1(DI)
	MOVQ	BX, (g_stack+stack_lo)(DI)
	MOVQ	SP, (g_stack+stack_hi)(DI)
```
设置g0的栈信息，设置了栈的地址开始与结束位置，分配大约64k空间。

##### cgo_init
判断是否存在 _cgo_init ,如果有就执行，执行完之后重新设置g0的栈地址

#### tls

```asm
#ifdef GOOS_plan9
	// skip TLS setup on Plan 9
	JMP ok
#endif
#ifdef GOOS_solaris
	// skip TLS setup on Solaris
	JMP ok
#endif
#ifdef GOOS_darwin
	// skip TLS setup on Darwin
	JMP ok
#endif

	LEAQ	runtime·m0+m_tls(SB), DI
	//settls 位于 go1.12.5/src/runtime/sys_linux_amd64.s:606
	CALL	runtime·settls(SB)

	// store through it, to make sure it works
	get_tls(BX)
	MOVQ	$0x123, g(BX)
	MOVQ	runtime·m0+m_tls(SB), AX
	CMPQ	AX, $0x123
	JEQ 2(PC)
	CALL	runtime·abort(SB)
```
在plan 9, solaris ,darwin 上都直接跳过tls的设置。


#### runtime.args
```asm
	MOVL	16(SP), AX		// copy argc
	MOVL	AX, 0(SP)
	MOVQ	24(SP), AX		// copy argv
	MOVQ	AX, 8(SP)
	CALL	runtime·args(SB)
```
runtime.args 位于 go1.12.5/src/runtime/runtime1.go:60
主要作用是读取参数以及获取环境变量；

#### runtime.osinit
主要设置cpu 数量

### runtime.schedinit
位于 go1.12.5/src/runtime/proc.go:526
主要作用 初始化堆栈, 参数，gc , sched。

接下来主要是创建一个goroutine,然后放到队列中，启动mstart 进行调度 运行第一个goroutine（runtime.main）


