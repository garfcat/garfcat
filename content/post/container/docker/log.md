---
title: "docker 容器日志过大问题" # Title of the blog post.
date: 2024-01-29T14:20:46+08:00 # Date of post creation.
description: "docker 容器日志过大问题" # Description used for search engine.
featured: true # Sets if post is a featured post, making appear on the home page side bar.
draft: false # Sets whether to render this page. Draft of true will not be rendered.
toc: false # Controls if a table of contents should be generated for first-level links automatically.
# menu: main
featureImage: "/images/cat.png" # Sets featured image on blog post.
thumbnail: "/images/cat.png" # Sets thumbnail image appearing inside card on homepage.
shareImage: "/images/path/share.png" # Designate a separate image for social media sharing.
codeMaxLines: 10 # Override global value for how many lines within a code block before auto-collapsing.
codeLineNumbers: false # Override global value for showing of line numbers within code block.
figurePositionShow: true # Override global value for showing the figure label.
categories:
  - Technology
tags:
  - docker
  - log
# comment: false # Disable comment if false.
---



## docker 日志文件存放哪些日志  
Docker容器的标准输出（stdout）和标准错误输出（stderr）被发送到容器的日志驱动程序，这些日志可以通过 docker logs 命令来访问。默认情况下，Docker将这些日志存储在宿主机上的 /var/lib/docker/containers/<container-id>/ 目录中，每个容器都有一个单独的目录。

## 如何清理 docker 日志文件  
清理Docker日志文件的方法通常包括手动清理以及使用工具自动清理；

### 业务控制   
减少业务的输出，可以控制日志量，但这并不是一个好的方法。

### 临时清理  

可以通过以下命令临时清理，但这只是临时的方法，不能根治。
```shell
logs=$(find /var/lib/docker/containers/ -name *-json.log*) ; for log in $logs ; do echo "clean logs : $log" ; cat /dev/null > $log ; done

```
### Docker日志驱动配置  

使用Docker的日志驱动配置选项来限制日志文件大小和保留时间。你可以在运行容器时使用 --log-opt 选项来配置日志的最大大小和保留时间，从而使Docker自动清理过期的日志。    
关于日志驱动配置可以分为以下两个方法：  
1. 启动容器时进行设置  
```shell
# max-size 最大数值
# max-file 最大日志数
$ docker run -it --log-opt max-size=10m --log-opt max-file=3 nginx
```

2. 通过daemon.json 全局修改   
```shell
{
    "log-driver":"json-file",
    "log-opts":{
        "max-size" :"50m","max-file":"1"
    }
}
```
这个需要重启docker  .



选择清理方法取决于你的需求和环境。手动清理适用于简单的清理任务，而使用工具自动清理可以提高效率并降低人为错误的风险。 