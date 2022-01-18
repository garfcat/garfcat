---
title: "Golang程序性能pprof使用介绍"
date: 2021-03-29T20:30:20+08:00
---

对于Golang程序性能分析，pprof 可以说是一大利器，它是用来性能分析的工具，主要可以分析CPU使用情况、内存使用情况、阻塞情况、竞争互斥锁等性能问题。
整个分析主要分为三个部分：
1. 项目中引入相关的包；
2. 编译程序运行并收集运行时的数据；
3. 分析相关数据
# 引入并收集数据
Golang标准库中提供了两种引入方式：
1. runtime/pprof: 将程序运行时的性能分析数据写入到文件中，然后可通过pprof可视化分析工具进行分析；支持使用标准测试包构建的性能分析基准测试；
2. net/http/pporf: 通过HTTP Server的方式提供pprof可视化工具所需要的性能分析数据；

## runtime/pprof 
**支持基准测试**：以下命令在当前目录中运行基准测试并将 CPU 和内存配置文件写入 cpu.prof 和 mem.prof：
```shell
 go test -cpuprofile cpu.prof -memprofile mem.prof -bench .
```
**独立程序分析**：需要将以下代码添加到主函数中：
```golang
var cpuprofile = flag.String("cpuprofile", "", "write cpu profile `file`")
var memprofile = flag.String("memprofile", "", "write memory profile to `file`")

func main() {
    flag.Parse()
    if *cpuprofile != "" {
        f, err := os.Create(*cpuprofile)
        if err != nil {
            log.Fatal("could not create CPU profile: ", err)
        }
        if err := pprof.StartCPUProfile(f); err != nil {
            log.Fatal("could not start CPU profile: ", err)
        }
        defer pprof.StopCPUProfile()
    }

    // ... rest of the program ...

    if *memprofile != "" {
        f, err := os.Create(*memprofile)
        if err != nil {
            log.Fatal("could not create memory profile: ", err)
        }
        runtime.GC() // get up-to-date statistics
        if err := pprof.WriteHeapProfile(f); err != nil {
            log.Fatal("could not write memory profile: ", err)
        }
        f.Close()
    }
}
```
## net/http/pporf
通过 import _ "net/http/pprof" 可以引入该包，如果你的程序没有http server,则需要添加类似以下代码：
```golang
go func() {
	log.Println(http.ListenAndServe("localhost:6060", nil))
}()
```
http server所有路径都是以 /debug/pprof/ 开头；本地访问 http://localhost:6060/debug/pprof 可以看到一个概览，展示的是pprof可以采集数据；
```shell 
/debug/pprof/

Types of profiles available:
Count	Profile
1	allocs              ## 内存分配情况的采样
0	block               ## 阻塞情况的采样
0	cmdline             ## 显示命令启动信息
7	goroutine           ## 当前所有goroutines的堆栈信息
1	heap                ## 堆上内存申请情况的采样
0	mutex               ## 锁竞争的采样信息
0	profile             ## CPU使用情况的采样
8	threadcreate        ## 系统线程创建的堆栈跟踪信息
0	trace               ## 程序运行跟踪信息
full goroutine stack dump
Profile Descriptions:

allocs: A sampling of all past memory allocations
block: Stack traces that led to blocking on synchronization primitives
cmdline: The command line invocation of the current program
goroutine: Stack traces of all current goroutines
heap: A sampling of memory allocations of live objects. You can specify the gc GET parameter to run GC before taking the heap sample.
mutex: Stack traces of holders of contended mutexes
profile: CPU profile. You can specify the duration in the seconds GET parameter. After you get the profile file, use the go tool pprof command to investigate the profile.
threadcreate: Stack traces that led to the creation of new OS threads
trace: A trace of execution of the current program. You can specify the duration in the seconds GET parameter. After you get the trace file, use the go tool trace command to investigate the trace.
```


# 分析
无论是 runtime/pprof 还是net/http/pporf 都是为收集程序运行时的采样数据，对于分析数据我们还要借助工具 go tool pprof， 以下以http server为例：
1. CPU分析
Demo如下：
```golang
package main

import (
	"log"
	"net/http"
	_ "net/http/pprof"
	"time"
)

func Bug() {
	for {
		for i := 0; i < 10000000000; i++ {
		}
		time.Sleep(1 * time.Second)
	}
}
func main() {
	go Bug()
	log.Println(http.ListenAndServe("localhost:6060", nil))
}
```
```sbtshell
go tool pprof http://localhost:6060/debug/pprof/profile
```
执行以上命令，可以通过http 获取到CPU的采样信息并通过go tool pprof进行分析，在进入交互式命令行后，可以输入top来查看占用CPU较高的函数
```sbtshell
(pprof) top
Showing nodes accounting for 19990ms, 99.65% of 20060ms total
Dropped 19 nodes (cum <= 100.30ms)
      flat  flat%   sum%        cum   cum%
   18740ms 93.42% 93.42%    19760ms 98.50%  main.Bug
    1010ms  5.03% 98.45%     1010ms  5.03%  runtime.asyncPreempt
     240ms  1.20% 99.65%      240ms  1.20%  runtime.nanotime1
         0     0% 99.65%      250ms  1.25%  runtime.mstart
         0     0% 99.65%      250ms  1.25%  runtime.mstart1
         0     0% 99.65%      240ms  1.20%  runtime.nanotime (inline)
         0     0% 99.65%      250ms  1.25%  runtime.sysmon
```
flat：当前函数上运行耗时；  
flat%：当前函数的运行耗时占 CPU 运行耗时比例；  
sum%： 前面每一行的 flat 占比总和；  
cum： 当前函数加上该函数调用函数的总耗时；   
cum%： 当前函数加上该函数调用函数的总耗时占用CPU运行耗时的比例；

通过top 可以看到占用CPU较高的函数，然后可以通过 *list 函数名* 命令来查看某个函数的更细致的分析
```sbtshell
(pprof) list Bug
Total: 20.06s
ROUTINE ======================== main.Bug in /Users/xiefei/repo/post/debug/main.go
    18.74s     19.76s (flat, cum) 98.50% of Total
         .          .      6:	_ "net/http/pprof"
         .          .      7:	"time"
         .          .      8:)
         .          .      9:
         .          .     10:func Bug() {
         .      770ms     11:	for {
    18.74s     18.98s     12:		for i := 0; i < 10000000000; i++ {
         .          .     13:		}
         .       10ms     14:		time.Sleep(1 * time.Second)
         .          .     15:	}
         .          .     16:}
         .          .     17:
         .          .     18:func main() {
         .          .     19:	go Bug()
```
由该命令可以看出 for 循环那段代码占用的CPU较高，从而定位问题；

另外我们还可以通过web 命令查看将采样数据图形化展示出来；

![web](/bug.png)
图中的箭头代表的是函数的调用，箭头上的值代表的是该方法的采样值，这里是CPU耗时，框越大的函数CPU占用就越高，框内表示的就是
flat、flat%、cum、cum%.

另外我们还可以通过以下命令获取Profile并在启动一个web服务在浏览器中进行分析：
```sbtshell
go tool pprof -http=:8888 http://localhost:6060/debug/pprof/profile?second=10s
```
从浏览器中可以看到top、source、graph、火焰图等信息；
![top](/performance/web-pprof-top.png)
top 与命令行top显示是基本一致;
![source](/performance/web-pporf-source.png)
source 与 命令行list 显示基本一致；
![graph](/performance/graph.png)
graph 与命令web 显示一致；
![火焰图](/performance/flame.png)
火焰图的Y轴表示函数调用栈。X轴表示该函数占用的CPU时间的百分比，越宽代表占用的CPU时间就越多。



## 内存
```sbtshell
go tool pprof http://localhost:6060/debug/pprof/heap
```
```sbtshell
go tool pprof -http=:8888 http://localhost:6060/debug/pprof/heap
```
内存分析通过以上命令获取相应的数据，分析方法与CPU基本一样，不过有几个术语需要解释以下：  
inuse_space:正在使用的分配空间;  
inuse_objects:正在使用的分配对象数;  
aloc_objects:累计的分配对象数;  
aloc_space:累计的分配空间;  

# 总结
pprof 确实是分析Golang程序的一大利器，我们一般使用基本分为三步：
1.将代码加入到项目中 
2. 收集相关数据
3.分析数据；在分析时我们也一般使用top list 或者火焰图来分析；  

# 参考
[runtime/pprof](https://pkg.go.dev/runtime/pprof)  
[net/http/pprf](https://pkg.go.dev/net/http/pprof)  
[Profiling your Golang app in 3 steps](https://coder.today/tech/2018-11-10_profiling-your-golang-app-in-3-steps/)   
