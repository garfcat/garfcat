---
title: "Command"
date: 2019-06-20T15:52:31+08:00
draft: true
---

# 镜像
1.显示
```bash
docker images 相当于 docker image list

$ docker images
REPOSITORY                                    TAG                 IMAGE ID            CREATED             SIZE
busybox                                       latest              59788edf1f3e        8 months ago        1.15MB
golang                                        1.9-stretch         ef89ef5c42a9        11 months ago       750MB
swarm                                         latest              ff454b4a0e84        12 months ago       12.7MB
```  
2.删除
```bash
 docker rmi [OPTIONS] IMAGE [IMAGE...]
 docker image rm [OPTIONS] IMAGE [IMAGE...]
```
可以使用一些组合命令来删除；  
以下是删除所有的镜像 
```bash
docker image rm $(docker images)
``` 
3.保存

```bash
docker save 0bd81a8c93f7 -o test.tar
```

4.导入
```bash
docker load < test.tar
```