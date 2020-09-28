---
title: "golang test 使用教程"
date: 2020-09-27T16:15:18+08:00
draft: false
tags: [ "go", "test","testing" ]
series: ["golang"]
categories: ["编程语言"]
---

单测是提高代码质量的重要一环,在提交代码尤其是开源社区单测一般是必需要随代码一起提交的,下面我们来看一下Golang中是如何写单元测试的。
Go中提供了专门用来写单元测试的包 testing， 运行时只需要 go test  即可。
单元测试主要分为以下三类：
- 功能测试（Test）
- 性能测试（Benchmark）
- 示例测试（Example）

测试文件名称一般是源代码文件加上 "_test.go", 比如 源代码文件为 add.go ，则测试文件名称为add_test.go。

在展开单元测试之前先讲下,testing包中的输出函数：
-  t.Log() :  正常日志输出;
-  t.Errorf():  错误日志输出，当前函数继续运行;
-  t.Fatalf():  错误日志输出，当前函数立刻退出；

## 功能测试
测试函数有两点约定：
1. 函数名必需以Test为前缀，如需要测试Add函数则名称应该为
TestAdd;
2. 函数参数必需为 t * testing.T;
完整的功能测试如下所示：
```golang
// add.go
func Add(a int, b int) int {
    return a + b 
}

// add_tesg.go
func TestAdd(t *testing.T){
    a := 1
    b := 2 
    want := a + b 
    got := Add(a, b)
    if want != got {
        t.Errorf("Add(%d, %d) = %d, want %d", a, b, got, want)
    }
}
```
在运行的时候可以使用 go test 执行该目录下的所有功能测试函数， 也可以通过 go test -run Xxxx 指定特定测试函数运行，-v 可以显示每个测试函数的执行结果， 如下所示：

```shell
➜    go test -v
=== RUN   TestAdd
--- PASS: TestAdd (0.00s)
PASS
ok  	learn/golang/test	0.185s
```

# 性能测试
性能测试函数有两点约定：
1. 函数名必需以Benchmark为前缀，如需要测试Add函数则名称应该为
BenchmarkAdd;
2. 函数参数必需为 b * testing.B;
完成测试函数如下所示：
```golang
func BenchmarkRandInt(b *testing.B) {
	for i := 0; i < b.N; i++ {
		rand.Int()
	}
}
```
在运行的时候可以执行如下命令：
1. go test -bench=.  ：执行该目录下的所有测试函数(包含功能测试和性能测试)；
2. go test -bench=.  -run=^$  ：执行该目录下的性能测试函数；
3. go test -bench=BenchmarkRandInt -run=^$: 执行性能测试函数BenchmarkRandInt；

-bench: 只有有个该标志才会执行性能测试函数；
-run: 这个标志表示要执行哪些功能测试函数，默认是全部，^$ 表示空，即不执行功能测试函数；

执行结果如下：
```sbtshell
➜    go test -bench=BenchmarkRandInt -run=^$
goos: darwin
goarch: amd64
pkg: learn/golang/test
BenchmarkRandInt-8   	70695550	        16.9 ns/op
PASS
ok  	learn/golang/test	1.956s
```
对于测试结果的输出，重点字段解释如下：
BenchmarkRandInt-8 ： 说明执行的测试函数是BenchmarkRandInt， 8说明使用的最大P是8个；
70695550： 执行的总次数；
16.9 ns/op ： 单次平均耗时；
另外如果执行测试函数前有一些耗时的操作，可以使用b.ResetTimer() 重置以下定时器；

## 示例测试
示例测试函数提供了运行并验证的功能，既可以当作文档又可以用来测试；
示例测试有如下约定：
1. 函数名必需以Example为前缀；
2. 通过注释 Output: 来说明正确的输出结果，，在运行测试时，go 会将示例函数的输出和 "Output:" 注释中的值做比较；
3. 如果输出的顺序不固定可以使用 "Unordered output:" 开头的注释；
完整测试如下所示：
```golang
func ExamplePerm() {
    for _, value := range Perm(5) {
        fmt.Println(value)
    }
    // Unordered output: 4
    // 2
    // 1
    // 3
    // 0
}
```


# 参考
[golang testing](https://golang.org/pkg/testing/)
 




