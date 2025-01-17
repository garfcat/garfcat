---
title: "Google 的 Borg 大规模集群管理<译>" # Title of the blog post.
date: 2023-04-04T10:16:04+08:00 # Date of post creation.
description: "Article description." # Description used for search engine.
featured: true # Sets if post is a featured post, making appear on the home page side bar.
draft: true # Sets whether to render this page. Draft of true will not be rendered.
toc: true # Controls if a table of contents should be generated for first-level links automatically.
# menu: main
# featureImage: "/images/cat.png" # Sets featured image on blog post.
# thumbnail: "/images/cat.png" # Sets thumbnail image appearing inside card on homepage.
shareImage: "/images/path/share.png" # Designate a separate image for social media sharing.
codeMaxLines: 10 # Override global value for how many lines within a code block before auto-collapsing.
codeLineNumbers: false # Override global value for showing of line numbers within code block.
figurePositionShow: true # Override global value for showing the figure label.
categories:
  - borg
tags:
  - Large-scale cluster management at Google with Borg
  - borg
# comment: false # Disable comment if false.
---

## 摘要  
Google 的 Borg 系统是一个集群管理器，能够运行数百万个作业，来自于数千个不同的应用程序，在多个集群上运行，每个集群有数以万计的机器。通过结合准入控制、高效的任务打包、超额承诺和进程级性能隔离，它实现了高利用率。它通过支持运行时特性和调度策略来支持高可用性应用程序，这些特性能够最小化故障恢复时间，并减少相关故障的概率。Borg 通过提供声明性作业规范语言、名称服务集成、实时作业监视和分析和模拟系统行为的工具，为其用户简化了工作。我们介绍了 Borg 系统架构和特性的概述、重要的设计决策、一些策略决策的定量分析以及对使用它十年的运营经验的定性考察的总结。  

## 介绍  
我们内部称为 Borg 的集群管理系统，能够接受、调度、启动、重新启动和监控 Google 运行的所有应用程序。本文解释了其工作原理。Borg 提供了三个主要的好处：它（1）隐藏了资源管理和故障处理的细节，使其用户可以专注于应用程序开发；（2）具有非常高的可靠性和可用性，并支持具有相同特性的应用程序；（3）使我们能够有效地在数以万计的机器上运行工作负载。Borg 不是第一个解决这些问题的系统，但它是少数几个能够以这种规模、这种弹性和完整性运行的系统之一。本文围绕这些主题展开，最后总结了我们在生产环境中运行 Borg 十多年所得出的一些定性观察。  