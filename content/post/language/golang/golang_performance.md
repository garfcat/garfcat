---
title: "Golang程序性能pprof使用介绍"
date: 2021-03-29T20:30:20+08:00
---

对于Golang程序性能分析，pprof 可以说是一大利器，它是用来性能分析的工具，主要可以分析CPU使用情况、内存使用情况、阻塞情况、竞争互斥锁等性能问题。

# 如何使用
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
无论是 runtime/pprof 还是net/http/pporf 都是为收集程序运行时的采样数据， 对于分析数据我们还要借助工具 go tool pprof， 以下以http server为例：

1. CPU分析

```sbtshell
go tool pprof http://localhost:6060/debug/pprof/profile
```
执行以上命令，可以通过http 获取到CPU的采样信息并通过go tool pprof进行分析，在进入交互式命令行后，可以输入top来查看占用CPU较高的函数
```sbtshell
(pprof) top
Showing nodes accounting for 25.31s, 99.14% of 25.53s total
Dropped 12 nodes (cum <= 0.13s)
      flat  flat%   sum%        cum   cum%
    23.24s 91.03% 91.03%     25.31s 99.14%  main.Bug
     2.07s  8.11% 99.14%      2.07s  8.11%  runtime.asyncPreempt
         0     0% 99.14%      0.21s  0.82%  runtime.mstart
         0     0% 99.14%      0.21s  0.82%  runtime.mstart1
         0     0% 99.14%      0.21s  0.82%  runtime.sysmon
```
flat：当前函数上运行耗时；  
flat%：当前函数的运行耗时占 CPU 运行耗时比例；  
sum%： 前面每一行的 flat 占比总和；  
cum： 当前函数加上该函数调用函数的总耗时；   
cum%： 当前函数加上该函数调用函数的总耗时占用CPU运行耗时的比例；


  



# 参考
[runtime/pprof](https://pkg.go.dev/runtime/pprof)  
[net/http/pprf](https://pkg.go.dev/net/http/pprof)
