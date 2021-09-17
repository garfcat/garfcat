---
title: "Rook Edgefs 介绍" # Title of the blog post.
date: 2021-09-17T10:29:11+08:00 # Date of post creation.
description: "Article description." # Description used for search engine.
featured: true # Sets if post is a featured post, making appear on the home page side bar.
draft: false # Sets whether to render this page. Draft of true will not be rendered.
toc: true # Controls if a table of contents should be generated for first-level links automatically.
# menu: main
featureImage: "/images/path/file.jpg" # Sets featured image on blog post.
thumbnail: "/images/path/thumbnail.png" # Sets thumbnail image appearing inside card on homepage.
shareImage: "/images/path/share.png" # Designate a separate image for social media sharing.
codeMaxLines: 10 # Override global value for how many lines within a code block before auto-collapsing.
codeLineNumbers: false # Override global value for showing of line numbers within code block.
figurePositionShow: true # Override global value for showing the figure label.
categories:
  - Storage
tags:
  - edgefs-rook
  - rook
  - edgefs
# comment: false # Disable comment if false.
---
## 什么是 EdgeFS 
EdgeFS 是使用Go和C实现的高性能、可容错以及低延迟的对象存储系统，可以对来自本地，私有/公有云或者小型(loT)设备的数据进行地理透明地访问。  
EdgeFS 能够跨越无限数量的地理位置分布的站点（地理站点），相互连接，作为在 Kubernetes 平台上运行的一个全局名称空间数据结构，提供持久、容错和高性能的完全兼容的 S3 Object API 有状态的 Kubernetes 应用程序和 CSI 卷。
在每个Geo站点，EdgeFS 节点在物理或虚拟节点上部署为容器（StatefulSet），汇集可用存储容量并通过兼容的 S3/NFS/iSCSI/etc 存储模拟协议为在相同或专用服务器上运行的云原生应用程序提供存储容量。

EdgeFS 类似于 "git", 将所有的修改都完全版本化并且全局不可变，通过模拟存储标准协议（如S3、NFS，甚至iSCSI等块设备）以高性能和低延迟的方式访问 Kubernetes 持久卷。通过完全版本化的修改、完全不可变的元数据和数据，用户数据可以跨多个地理站点透明地复制、分发和动态预取。  
## 现状
EdgeFS 原本是 Nexenta 公司的开源项目（当时叫做 "NexentaEdge"，使用 Apache-2.0 License），后来 Nexenta 被名为 DataDirect Networks（DDN）的公司全资收购，然后 DDN 公司将 NexentaEdge 重命名为 EdgeFS，并选择将其闭源。 所以目前 EdgeFS 已经废弃了。不推荐使用。

## 设计
Rook 支持使用 Kubernetes 原语在 Kubernetes 上轻松部署 EdgeFS 地理站点。
![edgefs-rook](/static/k8s/storage/edgefs-rook.png)

当Rook在 Kubernetes 集群中运行后，Kubernetes PODs 或者外部应用可以 mount Rook管理的块设备和文件系统，也可以通过 S3/S3X API进行对象存储。Rook operator 自动配置存储组件并监控群集，以确保存储健康可用。  
Rook operator 是一个简单的容器，它具有引导和监视存储集群所需的所有功能。operator 将启动并监控 StatefSet storage Targets、gRPC manager 和 Prometheus 多租户仪表板。所有连接的设备（或目录）将提供池存储站点。然后，存储站点可以作为一个全局名称空间数据结构轻松地相互连接。operator 通过初始化POD和运行服务所需的其他工件来管理目标、横向扩展NFS、对象存储（S3/S3X）和iSCSI卷的CRD。
operator 将监控存储目标，以确保群集正常运行。EdgeFS将动态处理服务故障切换，以及可能随着集群的增长或缩小而进行的其他调整。
EdgeFS Rook operator 还提供了集成的CSI插件。部署在每个Kubernetes节点上的CSI POD。处理节点上所需的所有存储操作，例如连接网络存储设备、挂载NFS导出和动态资源调配。
Rook在golang实现。EdgeFS使用Go和C实现，其中数据路径得到高度优化。
## 组成
![edgefs-components](/static/k8s/storage/edgefs-components.png)

edgefs 主要包含以下几个部分:  
grpc manager: 使用NFS/iSCSI CSI plugin时，提供对CSI plugin的请求进行平衡委托的功能。此外，还可作为可执行efscli命令的toolbox发挥功能。内部包好三个容器：  
    - rook-edgefs-mgr  
    - grpc: grpc-EFS代理工作。  
    - ui: 提供Edgefs dashboard。  
Target: EdgeFS 中的数据节点，处理HDD/SSD。有三个POD运行：  
    - daemon： 内部有CCow等进程运行  
    - corosync： 在应用程序OSS中实现HA， 监控集群节点的健康状态。  
    - auditd  
NFS: 提供NFS服务。 Pod内除了NFS Ganesha外，还启动了GRPC进程。  
S3: 提供S3服务，Pod内启动GRPC进程。  
S3X：提供S3X服务。在Pod内启动 rook-edgefs-s3x s3-proxy两个容器。  
iSCSI: 提供iSCSI服务， Pod内启动GRPC进程。  
CSI插件： 从Rook v1.2开始，可以使用NFS/iSCSI的CSI插件。  
ISGW： inter-Segment Gateway, 连接其他集群。   



## 参考
[edgefs-storage](https://rook.io/docs/rook/v1.0/edgefs-storage.html)
[开发者被 GitHub 要求下架开源项目仓库，因为其上游项目未“开源”](https://www.oschina.net/news/115501/recevied-an-dmca-takedown-from-github)