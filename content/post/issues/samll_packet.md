---
title: "网络传输小包引起的性能问题" # Title of the blog post.
date: 2021-06-16T23:00:29+08:00 # Date of post creation.
description: "Article description." # Description used for search engine.
featured: true # Sets if post is a featured post, making appear on the home page side bar.
draft: true # Sets whether to render this page. Draft of true will not be rendered.
---

# 背景
我们边缘设备的数据目前是通过应用 data manager (数据管理服务)存储到hbase中,但是该服务负载较高,请求处理延迟高，随着设备数量的上升，这个问题越来越明显，所以是时候处理一下了。

# 问题定位思路
定位应用性能问题首先要看的就是系统的top ,观察 应用CPU 系统CPU 平均负载


# 

