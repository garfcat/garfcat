---
title: "一文读懂iptables/netfilter附带实战" # Title of the blog post.
date: 2022-10-13T14:14:13+08:00 # Date of post creation.
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
  - iptables
  - docker
# comment: false # Disable comment if false.
---

## 简介
iptables 是一个命令行工具，用来配置包过滤的规则的，而真正实现这些规则的程序位于内核层，叫做 netfilter, 可以讲iptables理解为netfilter的客户端，iptables 与 netfilter 共同组成了包过滤软件。
平常工作交流中 iptables 也经常代指该内核级防火墙，iptables 用于 ipv4, 相应的 ip6tables 用于 IPv6。  
![netfilter 全景图](/iptables/Netfilter-packet-flow.svg.png)  
## 概念介绍
### hook 
iptables 在内核是对数据包做修改、转发、丢弃等操作的，而这些操作都是在一个个 hook 上完成的，hook 就是注册数据包处理函数的地方。hook点都是预定义好的，一共划分了五个hook点，分别为:  
- NF_IP_PRE_ROUTING: 接收到的包进入协议栈后由该hook上注册的函数来处理，这是在查询路由之前;  
- NF_IP_LOCAL_IN: 查询路由后判断数据包是发往本机的，则首先进入该hook点，由该hook点上注册的函数来处理;  
- NF_IP_FORWARD: 查询路由后判断数据包是不是本机的，则进入该hook点，由该hook点上注册的函数来处理;  
- NF_IP_LOCAL_OUT: 本机发出的数据包首先进入该hook点，由该hook点上注册的函数来处理;  
- NF_IP_POST_ROUTING: 数据包在发出本机之前，路由判断之后， 进入该hook点，由该hook点上注册的函数来处理;  

### 表、链、规则
iptables 是由表(table)来组织的，而表又是由 链(chain) 组成，链中包含了一个或者多个规则(rule)，规则既是对数据包处理的具体定义，所以总体来看
iptables -> table -> chain -> rule, 具体如下图所示:
![iptables过程](/iptables/iptables.png)  
（图片引用自https://wiki.archlinux.org/title/iptables_(%E7%AE%80%E4%BD%93%E4%B8%AD%E6%96%87)）

### 链


## 参考  
[iptables](https://www.netfilter.org/projects/iptables/index.html)  
[iptables (简体中文)](https://wiki.archlinux.org/title/iptables_(%E7%AE%80%E4%BD%93%E4%B8%AD%E6%96%87))   
[A Deep Dive into Iptables and Netfilter Architecture](https://www.digitalocean.com/community/tutorials/a-deep-dive-into-iptables-and-netfilter-architecture)  