---
title: "golang 栈结构"
date: 2019-06-15T16:41:11+08:00
draft: false
---

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
无参数无本地变量栈结果是如下所示

![没有参数没有本地变量](https://raw.githubusercontent.com/garfcat/garfcat/master/static/fpspnoargs.png)

通过如下函数来验证

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


#### 无参数无本地变量

```asm
#include "textflag.h" //

TEXT ·SpFpArgs(SB),NOSPLIT,$0-24
    LEAQ (SP), AX
    LEAQ a+0(SP), BX
    LEAQ b+0(FP), CX
    MOVQ AX, ret+24(FP)
    MOVQ BX, ret+32(FP)
    MOVQ CX, ret+40(FP)
    RET
    
```
```golang
package main

import "fmt"

func SpFpArgs(int, int, int) (int, int, int) // 汇编函数声明
func main()  {
	e,f,g   := SpFpArgs(1, 2, 3)
	fmt.Printf("硬SP[%d] 伪SP[%d] FP[%d]\n", e, f, g)
}

```
```bash
$ ./spfp
硬SP[824634216048] 伪SP[824634216048] FP[824634216056]
```

由此可以看出这种情况硬件SP与伪SP相等，FP = 伪SP+8 

### 有本地变量
在有本地变量情况下，在X86 和 ARM 中栈结构是不同的，如下所示：
```bash


// Stack frame layout
//
// (x86)
// +------------------+
// | args from caller |
// +------------------+ <- frame->argp
// |  return address  |
// +------------------+
// |  caller's BP (*) | (*) if framepointer_enabled && varp < sp
// +------------------+ <- frame->varp
// |     locals       |
// +------------------+
// |  args to callee  |
// +------------------+ <- frame->sp
//
// (arm)
// +------------------+
// | args from caller |
// +------------------+ <- frame->argp
// | caller's retaddr |
// +------------------+ <- frame->varp
// |     locals       |
// +------------------+
// |  args to callee  |
// +------------------+
// |  return address  |
// +------------------+ <- frame->sp

```
我们在这里主要关注X86， 在有本地变量的情况，在本地变量和参数之间会插入函数返回值和 BP 寄存器，但是BP寄存器的插入必须满足两点要求：
1. 函数的栈帧大于0；
2. 满足条件
```golang
func Framepointer_enabled(goos, goarch string) bool {
  return framepointer_enabled != 0 && goarch == "amd64" && goos != "nacl"
}
```

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
[go函数调用](https://lrita.github.io/2017/12/12/golang-asm/#go%E5%87%BD%E6%95%B0%E8%B0%83%E7%94%A8)