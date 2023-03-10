---
title: "设备硬件信息获取" # Title of the blog post.
date: 2023-03-07T14:08:45+08:00 # Date of post creation.
description: "Article description." # Description used for search engine.
featured: true # Sets if post is a featured post, making appear on the home page side bar.
draft: false # Sets whether to render this page. Draft of true will not be rendered.
toc: false # Controls if a table of contents should be generated for first-level links automatically.
# menu: main
featureImage: "/images/path/file.jpg" # Sets featured image on blog post.
thumbnail: "/images/path/thumbnail.png" # Sets thumbnail image appearing inside card on homepage.
shareImage: "/images/path/share.png" # Designate a separate image for social media sharing.
codeMaxLines: 10 # Override global value for how many lines within a code block before auto-collapsing.
codeLineNumbers: false # Override global value for showing of line numbers within code block.
figurePositionShow: true # Override global value for showing the figure label.
categories:
  - linux
tags:
  - cpu id
  - 主板序列号
# comment: false # Disable comment if false.
---


## 背景
有时我们需要基于设备的硬件信息来生成唯一的序列号，本文从物理机和容器两个角度描述获取硬件信息的几种方式。


## 硬件信息
主要包括 cpu id, 主板序列号，
### CPU ID 
在2006年，Intel决定取消将唯一标识符（Unique Identifier，UID）分配给每个CPU的计划。在取消该计划后，没有任何一款Intel CPU具有可用的UID或类似的标识符。   

dmidecode -t processor | grep ID 命令获取的是处理器的ID号码，而不是CPU序列号。在过去，Intel的处理器ID号码与CPU序列号是相关的。但是，自从Intel取消了CPU序列号计划后，处理器ID号码已经成为处理器的唯一标识符。但是需要注意的是，处理器ID号码仅用于识别处理器的型号和版本，而不是用作安全或加密目的。处理器ID是一个用于唯一标识处理器型号和版本的数字或字符串。每个处理器型号都有一个唯一的处理器ID，该ID包含有关处理器的各种信息，例如生产商、处理器系列、制造工艺、特性等等。  

处理器ID是一个用于唯一标识处理器型号和版本的数字或字符串。每个处理器型号都有一个唯一的处理器ID，该ID包含有关处理器的各种信息，例如生产商、处理器系列、制造工艺、特性等等。  

以下是一个举例：  

假设您有一台计算机，其处理器型号为“Intel(R) Core(TM) i7-10700K CPU @ 3.80GHz”。您可以使用 dmidecode -t processor | grep ID 命令来获取该处理器的ID。对于这个处理器，处理器ID可能会显示为"0x906E9"。这个处理器ID包含有关处理器的信息，例如：

- "0x9"表示该处理器是第9代英特尔酷睿处理器（Intel Core Processor）。  
- "0x06"表示该处理器的系列为酷睿i7系列（Core i7 Series）。  
- "0xE9"表示该处理器的型号为i7-10700K。  
其他数字和字母则包含有关制造工艺、特性等方面的信息。  
处理器ID是一个用于唯一标识处理器的数字或字符串，它包含有关处理器型号和版本的各种信息，这些信息可以用于确定处理器的特性、性能和兼容性等方面。  
### 主板序列号
主板序列号(board id)是一串唯一的数字和字母组合，用于标识计算机主板的身份和生产信息。每个主板都有一个唯一的序列号，类似于身份证号码或者汽车的车辆识别码（VIN）。主板序列号通常被存储在主板上的电子芯片中，并可以通过操作系统或者特定的软件程序来获取

### 磁盘序列号
磁盘序列号是一个磁盘驱动器的唯一标识符。它是由硬盘制造商预先配置的，通常由一串数字或字母组成。


## 宿主机下的获取方式

### CPU ID 的获取方式
```shell
[root ~]# dmidecode -t processor | grep ID
	ID: E3 06 05 00 FF FB 8B 0F
	ID: E3 06 05 00 FF FB 8B 0F
```

### 主板序列号
```shell
[root ~]# dmidecode -t system | grep Serial
	Serial Number: d0d39011-8a53-4046-a08b-aaca77b2e783
```

### 磁盘序列号
```shell
[root ~]# lshw -class disk | grep serial
       serial: ZA1CGDL0
```
*注意：* 虚拟硬盘是无法获取序列号的
```shell
[root@baidu-173b11a20 ~]# lshw -class disk
  *-disk:0
       description: SCSI Disk
       product: QEMU HARDDISK // 虚拟磁盘
       vendor: QEMU
       physical id: 0.0.0
       bus info: scsi@2:0.0.0
       logical name: /dev/sda
       version: 2.5+
       size: 40GiB (42GB)
       capabilities: 5400rpm partitioned partitioned:dos
       configuration: ansiversion=5 logicalsectorsize=512 sectorsize=512 signature=000a43f6
```


## 容器内获取硬件信息
dmidecode 是通过 /dev/mem 来读取设备信息，/dev/mem 是 Linux 操作系统中一个特殊的文件，它允许用户直接访问系统的物理内存。在 Linux 内核启动时，会将系统的物理内存映射到虚拟地址空间中，用户可以通过访问 /dev/mem 文件来读写这些虚拟地址，进而读写物理内存。
默认情况下 Docker 容器是运行在一个隔离的沙箱环境中，没有特权访问主机的物理内存。如果要在容器内使用 dmidecode 获取硬件信息，则需要映射 /dev/mem 设备以及授予相应的权限。

### 权限授予
- privileged：这个选项会赋予容器完全的权限，包括访问主机上的所有设备和文件系统。
- SYS_RAWIO ：允许用户进程直接访问硬件设备，绕过操作系统的驱动程序，进行原始的输入/输出操作。这个权限通常用于开发底层硬件驱动程序和进行系统调试，因为它允许用户直接访问硬件资源，但也会增加系统安全性风险，因此必须谨慎使用。
按照最小授权原则 应该使用 SYS_RAWIO 来赋予权限。
### 挂载目录

使用--device参数来指定需要挂载的设备文件

### 测试容器
```shell
[root@crazy ~]# docker run -it --cap-add SYS_RAWIO   --device /dev/mem centos:new /bin/bash
[root@8f939efa0c9e /]# dmidecode -t processor | grep ID
	ID: E3 06 05 00 FF FB 8B 0F
	ID: E3 06 05 00 FF FB 8B 0F
[root@8f939efa0c9e /]# dmidecode -t system  | grep Serial
	Serial Number: d0d39011-8a53-4046-a08b-aaca77b2e783
```




