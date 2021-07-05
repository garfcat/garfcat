---
title: "网络传输小包引起的性能问题" # Title of the blog post.
date: 2021-06-16T23:00:29+08:00 # Date of post creation.
description: "Article description." # Description used for search engine.
featured: true # Sets if post is a featured post, making appear on the home page side bar.
draft: true # Sets whether to render this page. Draft of true will not be rendered.
---
最近优化了一个服务，借这次优化顺便总结一下性能优化的相关的知识点。
# 背景
线上有个服务负载较高，但是CPU利用率相对来说不是很高，该服务主要作用是将数据解析后通过 trift 写入到hbase.
# 问题定位
首先通过 top 查看系统运行情况，如下图所示
![](/static/issues/performance/top.png)

从 top 上来可以看到几点可疑之处：
1. 平均负载为8.52 : 8核机器上负载超过了8,说明系统负载已经很高；
2. CPU利用率: 


# 

