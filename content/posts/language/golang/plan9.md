---
title: "Plan9"
date: 2019-06-15T16:41:11+08:00
draft: true
---

# plan9

# 程序组成
程序由代码和数据组成，数据又有静态与动态之分；  
动态数据：存放在堆区和栈区；  
静态数据：静态只读数据可以放在代码区，也可以放在特定的只读数据区；  
可读写的已初始化的静态数据放在数据区，可读写的未初始化的静态数据放在bss区；  



# 寄存器
## 伪寄存器
- FP(Frame pointer): 表示参数以及返回值的基地址；
  通过 SYMBOL+/-ffset(FP)
- PC(Program counter): 跳转寄存器，存储下一条指令地址；
- SB(Static base pointer): 全局静态起始地址.  
- SP(Stack pointer): 表示本地变量的起始地址；  
    使用方式 symbol + offset(SP), 例如第一个变量 local0 + (0)SP , local0 只是定义一个符号，类似于 local0 := xxxx

这个四个伪寄存器在golang 汇编中经常被用到，尤其是SB和FP；  
SB 全局静态起始地址, foo(SB)表示foo在内存中的地址。这个语法有两个修饰符<> 和 +N，其中N是一个整数。 foo<>(SB)表示foo是一个私有元素只能在
当前文件中可见，就像是golang 首字母小写的变量或者函数。foo+8(SB)表示相对于foo 8字节的内存地址；*注意 这里是相对符号的地址*  
FP 用来引用程序的参数，这些引用是由编译器维护，通过该寄存器的偏移量来引用参数。在64位的机器上，0(FP)表示第一个参数，8(FP)表示第二个参数等等。为了程序的清晰与可读性，编译器强制在引用参数时使用名称。

## FP、 伪SP、 硬件SP之间的关系
SP分为伪SP和硬件寄存器SP，在栈桢为0的情况下 伪SP与硬件寄存器SP相等。可以使用有无symbol来区分是哪个寄存器： 有symbol 例如 foo-8(SP)表示伪寄存器，8(SP)表示硬件寄存器。  


### 栈结构

#### 无参数无本地变量

```asm
#include "textflag.h" //

TEXT ·SpFp(SB),NOSPLIT,$0-32
    LEAQ (SP), AX   // 将硬件SP地址存储到AX
    LEAQ a+0(SP), BX  // 将伪SP地址存储到BX
    LEAQ b+0(FP), CX  // 将FP地址存储到CX
    MOVQ AX, ret+0(FP) // 将AX地址存储到第一个返回值
    MOVQ BX, ret+8(FP) // 将BX地址存储到第二个返回值
    MOVQ CX, ret+16(FP) // 将CX地址存储到第三个返回值
    MOVQ a+0(SP), AX  // 将SP 存储的值存储到AX， 也就是该函数的返回值
    MOVQ AX, ret+24(FP)  //将AX 放到第四个返回值
    RET
    
```
```golang
package main

import "fmt"

func SpFp() (int, int, int, int) // 汇编函数声明
func main()  {
	a,b,c, addr  := SpFp()
	fmt.Printf("硬SP[%d] 伪SP[%d] FP[%d] addr[%d] SpFp[%d] \n", a, b ,c,addr,SpFp )
}

```
```bash
$ ./spfp
硬SP[824634216112] 伪SP[824634216112] FP[824634216120] addr[17385428] SpFp[17385904]
```
由输出可以看出在没有参数没有本地变量情况下硬件SP与伪SP相等，FP = 伪SP+8 

```bash
$ dlv exec ./fpsp
Type 'help' for list of commands.
(dlv) b *17385428
Breakpoint 1 set at 0x10947d4 for main.main() ./main.go:7
(dlv)
```
由断点可以看出返回值就在main.go的第7行也就是 a,b,c, addr  := SpFp()



#### 有本地变量




## 举例


### 汇编
```bash
➜  plan9   GOOS=linux GOARCH=amd64 go tool compile -S direct_topfunc_call.go
"".add STEXT nosplit size=20 args=0x10 locals=0x0
        0x0000 00000 (direct_topfunc_call.go:5) TEXT    "".add(SB), NOSPLIT|ABIInternal, $0-16
        0x0000 00000 (direct_topfunc_call.go:5) FUNCDATA        $0, gclocals·33cdeccccebe80329f1fdbee7f5874cb(SB)
        0x0000 00000 (direct_topfunc_call.go:5) FUNCDATA        $1, gclocals·33cdeccccebe80329f1fdbee7f5874cb(SB)
        0x0000 00000 (direct_topfunc_call.go:5) FUNCDATA        $3, gclocals·33cdeccccebe80329f1fdbee7f5874cb(SB)
        0x0000 00000 (direct_topfunc_call.go:5) PCDATA  $2, $0
        0x0000 00000 (direct_topfunc_call.go:5) PCDATA  $0, $0
        0x0000 00000 (direct_topfunc_call.go:5) MOVL    "".b+12(SP), AX
        0x0004 00004 (direct_topfunc_call.go:5) MOVL    "".a+8(SP), CX
        0x0008 00008 (direct_topfunc_call.go:5) ADDL    CX, AX
        0x000a 00010 (direct_topfunc_call.go:5) MOVL    AX, "".~r2+16(SP)
        0x000e 00014 (direct_topfunc_call.go:5) MOVB    $1, "".~r3+20(SP)
        0x0013 00019 (direct_topfunc_call.go:5) RET
        0x0000 8b 44 24 0c 8b 4c 24 08 01 c8 89 44 24 10 c6 44  .D$..L$....D$..D
        0x0010 24 14 01 c3                                      $...
"".main STEXT size=65 args=0x0 locals=0x18
        0x0000 00000 (direct_topfunc_call.go:7) TEXT    "".main(SB), ABIInternal, $24-0
        0x0000 00000 (direct_topfunc_call.go:7) MOVQ    (TLS), CX
        0x0009 00009 (direct_topfunc_call.go:7) CMPQ    SP, 16(CX)
        0x000d 00013 (direct_topfunc_call.go:7) JLS     58
        0x000f 00015 (direct_topfunc_call.go:7) SUBQ    $24, SP
        0x0013 00019 (direct_topfunc_call.go:7) MOVQ    BP, 16(SP)
        0x0018 00024 (direct_topfunc_call.go:7) LEAQ    16(SP), BP
        0x001d 00029 (direct_topfunc_call.go:7) FUNCDATA        $0, gclocals·33cdeccccebe80329f1fdbee7f5874cb(SB)
        0x001d 00029 (direct_topfunc_call.go:7) FUNCDATA        $1, gclocals·33cdeccccebe80329f1fdbee7f5874cb(SB)
        0x001d 00029 (direct_topfunc_call.go:7) FUNCDATA        $3, gclocals·33cdeccccebe80329f1fdbee7f5874cb(SB)
        0x001d 00029 (direct_topfunc_call.go:7) PCDATA  $2, $0
        0x001d 00029 (direct_topfunc_call.go:7) PCDATA  $0, $0
        0x001d 00029 (direct_topfunc_call.go:7) MOVQ    $137438953482, AX
        0x0027 00039 (direct_topfunc_call.go:7) MOVQ    AX, (SP)
        0x002b 00043 (direct_topfunc_call.go:7) CALL    "".add(SB)
        0x0030 00048 (direct_topfunc_call.go:7) MOVQ    16(SP), BP
        0x0035 00053 (direct_topfunc_call.go:7) ADDQ    $24, SP
        0x0039 00057 (direct_topfunc_call.go:7) RET
        0x003a 00058 (direct_topfunc_call.go:7) NOP
        0x003a 00058 (direct_topfunc_call.go:7) PCDATA  $0, $-1
        0x003a 00058 (direct_topfunc_call.go:7) PCDATA  $2, $-1
        0x003a 00058 (direct_topfunc_call.go:7) CALL    runtime.morestack_noctxt(SB)
        0x003f 00063 (direct_topfunc_call.go:7) JMP     0
        0x0000 64 48 8b 0c 25 00 00 00 00 48 3b 61 10 76 2b 48  dH..%....H;a.v+H
        0x0010 83 ec 18 48 89 6c 24 10 48 8d 6c 24 10 48 b8 0a  ...H.l$.H.l$.H..
        0x0020 00 00 00 20 00 00 00 48 89 04 24 e8 00 00 00 00  ... ...H..$.....
        0x0030 48 8b 6c 24 10 48 83 c4 18 c3 e8 00 00 00 00 eb  H.l$.H..........
        0x0040 bf                                               .
        rel 5+4 t=16 TLS+0
        rel 44+4 t=8 "".add+0
        rel 59+4 t=8 runtime.morestack_noctxt+0
```
```bash
0x0000 00000 (direct_topfunc_call.go:5) TEXT    "".add(SB), NOSPLIT|ABIInternal, $0-16
```
- 0x0000 ：当前指令相对于当前函数的偏移量；
- TEXT    "".add(SB)： 表示 "".add(SB) 会存储到.text 段中也就是代码段



# 参考
https://9p.io/plan9/  
[指令查询](http://68k.hax.com/)  
[命令查询](https://9p.io/magic/man2html/1/8a)  
[Go的标准IDE：Acme文本编辑器](https://zhuanlan.zhihu.com/p/19902040)  
[A Quick Guide to Go's Assembler](https://golang.org/doc/asm)  
[golang 汇编](https://lrita.github.io/2017/12/12/golang-asm/)  
[汇编语言入门教程](https://www.ruanyifeng.com/blog/2018/01/assembly-language-primer.html)  
[[译]go 和 plan9 汇编](http://xargin.com/go-and-plan9-asm/)  
[split stacks](https://blog.brickgao.com/2019/01/27/split-stacks/)  
[How Stacks are Handled in Go](https://blog.cloudflare.com/how-stacks-are-handled-in-go/)
https://lrita.github.io/2017/12/12/golang-asm/#go%E5%87%BD%E6%95%B0%E8%B0%83%E7%94%A8