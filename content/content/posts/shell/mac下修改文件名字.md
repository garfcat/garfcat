---
title: "mac  sed 报错"
date: 2019-05-13T12:36:43+08:00
draft: false
tags: [ "sed", "mac", "shell"]
series: ["命令"]
categories: ["工具命令"]
---
mac 下的sed使用方法与linux略有不同，如果按照Linux方式使用sed -i替换文本时会报如下错误
```shell
$sed -i 's/xxxx/yyy/g' test
sed: 1: "test": extra characters at the end of p command
```
<!--more-->
解决方法
```bash
sed -i ""   "s/XX/YY/g"  test
```

============================================


sed 用法
```bash
sed: illegal option -- -
usage: sed script [-Ealn] [-i extension] [file ...]
       sed [-Ealn] [-i extension] [-e script] ... [-f script_file] ... [file ...]


-i 后边需要添加备份文件的后缀名,如果不需要可以使用"",但是不可以忽略

如 sed -i ".bak" 's/xxxx/yyy/g' test 会将替换后的文本写入test.bak
```




