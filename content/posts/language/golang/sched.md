---
title: "协程调度原理"
date: 2019-08-11T10:23:01+08:00
draft: true
---

# GMP调度模型
## 核心概念
- G ：即Goroutine ,使用关键字 go 即可创建一个协程来处理用户程序，如下所示：  
 ```golang
     go func() //创建协程来执行函数
 ``` 
- M ：Machine 系统抽象的线程，代表真正的机器资源，目前最多10000，超过这个数量会panic.  
- P ：Process,虚拟处理器，代表goroutine的上下文，用于关联G和M；P的数量可以通过GOMAXPROCS设置，默认为CPU核数；
- 本地队列（local queue）: 每个P关联有一个协程队列，该队列就是P的本地队列，新生成的协程放在该队列中，当该队列达到最大数量时，会将该队列的一般协程存入到全局队列中；
- 全局队列（global queue）: 当本地队列达到最大数量时，多余的协程就会存在全局队列中；

## 协程的状态
在go1.12.5/src/runtime/runtime2.go：15 定义有如下几个状态  
_Gidle: 值（0） 刚刚被创建，还没有初始化；  
_Grunnable： 值（1） 已经在运行队列中，只是此时没有执行用户代码,未分配栈；   
_Grunning：值（2）在执行用户代码，已经不在运行队列中，分配了M和P;  
_Gsyscall： 值（3）当前goroutine正在执行系统调用，已经不再运行队列中，分配了M;  
_Gwaiting： 值（4） 在运行时被阻塞，并没有执行用户代码，此刻的goroutine会被记录到某处（例如channel等待队列）  
_Gmoribund_unused: 值（5） 当前并未使用，但是已经在gdb中进行了硬编码；  
_Gdead： 值（6） 当前goroutine没有被使用，可能刚刚退出或者刚刚被初始化，并没有执行用户代码；  
_Genqueue_unused： 值（7） 当前并未使用； 
_Gcopystack：值（8）正在复制堆栈，并未执行用户代码，也没有在运行队列中；  


## 调度原理
![调度原理](https://raw.githubusercontent.com/garfcat/garfcat/master/static/gmp_pic.png)

### 新建G
1. 当使用go 关键字执行函数时，会创建一个G(goroutine);
2. 新创建的G，并不会添加到本地队列，而是添加到P关联的runnext中(runnext是一个指针变量，用来存放G的地址),runnext原来的G被放到本地队列中;  
    2.1 如果本地队列未满（最大256），则放置到队尾；  
    2.2 如果本地队列已满，则将本地队列的一半数量的G和runnext中原来的G存放到全局队列中；  
```golang
func schedule() {    
// only 1/61 of the time, check the global runnable queue for a G. 仅 1/61 的机会, 检查全局运行队列里面的 G.    
// if not found, check the local queue. 如果没找到, 检查本地队列.    
// if not found, 还是没找到 ?    
//     try to steal from other Ps. 尝试从其他 P 偷.   
 //     if not, check the global runnable queue. 还是没有, 检查全局运行队列.   
  //     if not found, poll network. 还是没有, 轮询网络.
  
  }

```

# 参考
https://studygolang.com/articles/20991 
https://studygolang.com/articles/11627  
https://mp.weixin.qq.com/s/Oos-aW1_khTO084v0jPlIA   