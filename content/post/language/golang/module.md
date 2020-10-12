---
title: "golang module 使用教程"
date: 2019-05-30T17:12:47+08:00
draft: false
tags: [ "go", "module" ]
series: ["golang"]
categories: ["编程语言"]
---

Go module 是golang最新的包管理工具，可以使依赖包版本信息更明确与可控。module 是关于Go packages的集合，存储在根目录下的go.mod文件中，go.mod 定义了模块的模块路径以及模块的依赖属性，依赖属性包含模块路径以及[特定寓意的版本信息](https://semver.org/lang/zh-CN/)。  
需要注意的是：在Go 1.13之前go module 在GOPATH下是默认不开启的，这是为了兼容的需要，如果需要使用go module可以在GOPATH/src外的路径创建go.mod文件。

本文会介绍Go module的一些基本用法； 
 - 常见命令
 - 创建一个模块  
 - 添加一个依赖  
 - 升级依赖  
 - 其他命令
# 常见命令
go mod 提供了以下命令
- download:  下载依赖包到本地缓存 ($GOPATH/pkg/mod), 该目录下的包所有项目共享;
- edit : 编辑go.mod;
- graph: 打印模块的依赖图;
- init: 在当前目录初始化mod;
- tidy : 添加缺失的依赖包并清理没有使用的包;
- vendor : 将依赖包复制到vendor目录;
- verify: 验证依赖是否正确;
- why : 解释为什么需要这个依赖;
# 创建一个模块
如前文所说在GOPATH外的创建一个目录，例如 ～/gomod/hello;  
执行一下子命令
```bash
 ~/gomod/hello$ go mod init example.com/hello
go: creating new go.mod: module example.com/hello
```

创建hello.go 
```golang
package hello

func Hello()string {
	return "Hello, world."
}
```

为使用SayHi,创建test文件 hello_test.go
```golang
package hello

import "testing"

func TestHello(t *testing.T) {
	want := "Hello, world."
	if got := Hello(); got != want {
		t.Errorf("Hello() = %s, want %s", got, want)
	}
}
```
执行测试用例
```bash
 ~/gomod/hello$ go test -run TestHello
PASS
ok  	example.com/hello	0.006s

```

# 添加一个依赖

```golang
package hello

import "rsc.io/quote"
func Hello()string {
	return quote.Hello()
}
```
执行
```bash
go: extracting rsc.io/quote v1.5.2
go: extracting rsc.io/sampler v1.3.0
PASS
ok  	example.com/hello	0.009s
```
此时会将代码下载到$GOPATH/pkg/mod目录下，之后运行不会重复下载，可以到go.mod已经更新了
```bash
module example.com/hello

go 1.12

require rsc.io/quote v1.5.2
```
使用 go list -m all 可以查看所有依赖
```bash
$ go list -m all
example.com/hello
golang.org/x/text v0.0.0-20170915032832-14c0d48ead0c
rsc.io/quote v1.5.2
rsc.io/sampler v1.3.0
```
此时目录下多了一个go.sum文件，这个文件是做什么的呢？
```bash
golang.org/x/text v0.0.0-20170915032832-14c0d48ead0c h1:qgOY6WgZOaTkIIMiVjBQcw93ERBE4m30iBm00nkL0i8=
golang.org/x/text v0.0.0-20170915032832-14c0d48ead0c/go.mod h1:NqM8EUOU14njkJ3fqMW+pc6Ldnwhi/IjpwHt7yyuwOQ=
rsc.io/quote v1.5.2 h1:w5fcysjrx7yqtD/aO+QwRjYZOKnaM9Uh2b40tElTs3Y=
rsc.io/quote v1.5.2/go.mod h1:LzX7hefJvL54yjefDEDHNONDjII0t9xZLPXsUe+TKr0=
rsc.io/sampler v1.3.0 h1:7uVkIFmeBqHfdjD+gZwtXXI+RODJ2Wc4O7MPEh/QiW4=
rsc.io/sampler v1.3.0/go.mod h1:T1hPZKmBbMNahiBKFy5HrXp6adAjACjK9JXDnKaTXpA=
```
可以看出该文件存储了包的路径 版本 还有校验值；每次执行命令时都会check 该校验是否与download目录下的是否一致；不一致就会报错
```bash
verifying rsc.io/quote@v1.5.2/go.mod: checksum mismatch
	downloaded: h1:Q15uSTpOVzCmer7yFUWKviBR7qLGLuYQ5zPmjACcaxQ=
	go.sum:     h1:LzX7hefJvL54yjefDEDHNONDjII0t9xZLPXsUe+TKr0=
```

# 升级依赖
加入要把quote包升级到其他版本，比如v3（需要提前知道升级的版本以及其中函数），
```golang
package hello

import (
	quoteV3 "rsc.io/quote/v3"
)
func Hello()string {
	return quoteV3.HelloV3()
}
```
运行 go test, 会自动下载V3
```bash
go test
go: downloading rsc.io/quote/v3 v3.1.0
go: extracting rsc.io/quote/v3 v3.1.0
PASS
ok  	example.com/hello	0.008s
```
查看 go.mod 
```bash
module example.com/hello

go 1.12

require (
	golang.org/x/text v0.3.2 // indirect
	rsc.io/quote v1.5.2
	rsc.io/quote/v3 v3.1.0
)
```
并没有删除 	rsc.io/quote v1.5.2 ，这需要执行 go mod tidy 来去除不使用的包。
```bash
$ go mod tidy
$ cat go.mod
module example.com/hello

go 1.12

require (
	golang.org/x/text v0.3.2 // indirect
	rsc.io/quote/v3 v3.1.0
)
```

# 其他命令

- replace 替换依赖项模块： 可以将包替换成另一个包或者不同版本;
- exclude 忽略依赖项模块；

# 总结

-  go mod init 创建一个模块，并创建文件go.mod;
-  go build , go test 还有其他关于编译的命令都会按需将依赖添加到go.mod;
-  go list -m all 输出当前模块所有的依赖；
-  go mod tidy 可以删除不使用的依赖；

# 参考
[using-go-modules](https://blog.golang.org/using-go-modules)