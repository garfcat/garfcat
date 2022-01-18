---
title: "Rook Edgefs 介绍" # Title of the blog post.
date: 2021-09-17T10:29:11+08:00 # Date of post creation.
description: "Article description." # Description used for search engine.
featured: true # Sets if post is a featured post, making appear on the home page side bar.
draft: false # Sets whether to render this page. Draft of true will not be rendered.
toc: true # Controls if a table of contents should be generated for first-level links automatically.
# menu: main
featureImage: "/static/k8s/storage/edgefs.png" # Sets featured image on blog post.
thumbnail: "/static/k8s/storage/edgefs.png" # Sets thumbnail image appearing inside card on homepage.
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
![edgefs-rook](/k8s/storage/edgefs-rook.png)

当Rook在 Kubernetes 集群中运行后，Kubernetes PODs 或者外部应用可以 mount Rook管理的块设备和文件系统，也可以通过 S3/S3X API进行对象存储。Rook operator 自动配置存储组件并监控群集，以确保存储健康可用。  
Rook operator 是一个简单的容器，它具有引导和监视存储集群所需的所有功能。operator 将启动并监控 StatefSet storage Targets、gRPC manager 和 Prometheus 多租户仪表板。所有连接的设备（或目录）将提供池存储站点。然后，存储站点可以作为一个全局名称空间数据结构轻松地相互连接。operator 通过初始化POD和运行服务所需的其他工件来管理目标、横向扩展NFS、对象存储（S3/S3X）和iSCSI卷的CRD。
operator 将监控存储目标，以确保群集正常运行。EdgeFS将动态处理服务故障切换，以及可能随着集群的增长或缩小而进行的其他调整。
EdgeFS Rook operator 还提供了集成的CSI插件。部署在每个Kubernetes节点上的CSI POD。处理节点上所需的所有存储操作，例如连接网络存储设备、挂载NFS导出和动态资源调配。
Rook在golang实现。EdgeFS使用Go和C实现，其中数据路径得到高度优化。
## 组成
![edgefs-components](/k8s/storage/edgefs-components.png)

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

## 什么是 CCow
Target Pod daemon容器中的运行着一个进程CCow进程,这个进程是做什么的呢? 根据 [nexenta](https://nexenta.com/solutions/openstack/cloud-copy-write-ccow) 的解释
> Nexenta Cloud Copy on Write™ (CCOW™) is an object storage system providing for versioned access to objects with chunk-based distributed deduplication. Nexenta CCOW is composed of a set of software components that can be deployed in various fashions within bare metal and/or Virtual Machine servers.

CCoW 是 Cloud Copy on Write 的缩写， 是一个对象存储系统，通过基于块的分布式重复数据删除提供对对象的版本化访问。Nexenta CCOW 由一组软件组件组成，这些组件可以以各种方式部署在裸机和/或虚拟机服务器中。使用裸机或虚拟机来部署一组“对象存储服务器”。服务器相互联合到持久存储，可以在任何单个服务器丢失的情况下继续存在。

![](/static/k8s/storage/CCow.png)

每一个对象存储的服务都包含以下几个组件:
- Object Storage Access Server: 对象存储访问服务, 为客户端提供一种或多种常规的对象存储访问方法。这些接口通常与现有协议兼容，例如 Amazon S3 或 OpenStack Swift Object Service。这些请求被转换成块请求和 Manifest 请求，然后转发到共同定位的块服务器和清单服务器。
- Chunk Server: 块服务器, 提供块的本地存储。一个块服务器的服务作用如下:
   - 存放数据块,每个存储请求都要提供一个从 Manifest Server 获取的事务ID 还有一个数据块的块ID.每个块使用可选压缩块有效负载的加密散列来标识。如果 Chunk 已知，Chunk Server 将成功完成 Chunk Put 事务，而无需传输负载。
   - 将数据块复制到数据块 ID 的指定数据块服务器
   - 当数据块服务器是该数据块的指定块服务器之一时，或者当有可用空间并且数据块有足够的流量来保证其本地保留时，保留块。
   - 在本地存储时检索块，否则从指定的块服务器之一检索块。
   - 维护对引用对象的引用。

- Manifest Server:  维护有关对象每个版本的元数据信息。对象组织在对应于传统对象服务容器（又名存储桶）的服务目录中。每个版本都由唯一的版本标识符标识，该标识符可由任何清单服务器根据全局同步时间戳和决胜局生成。唯一的版本标识符保证版本清单可以由不同的清单服务器以不同的顺序应用，同时仍然保证一旦所有事务都应用到所有服务器上，所有清单服务器最终将实现相同的版本清单。

![](/static/k8s/storage/LocalPermanentObjectStorageServer.png)

## 什么是 ISGW

![](/static/k8s/storage/ISGW.png)

ISGW（Inter-Segment Gateway）用于EdgeFS中Segment和云之间的全局命名空间同步功能。ISGW 跨多个站点异步分发块数据，以实现无缝、地理透明的数据访问。ISGW 提供以下功能。
当文件对象在 ISGW 链接到的数据的源站点上被修改时，ISGW 端点链接会检测并传播。这可以减少传输的数据量。

即使执行了文件更改，除非其哈希值是全局唯一的（如果有另一个匹配项），否则它不会被传输。因此，在全局空间进行去重，可以实现对传输数据的去重。

站点间ISGW传输方向可设置单向/双向通信。双向通信允许您修改整个全局命名空间中的相同文件/对象。您还可以控制不必要站点之间的通信和通信方向。

Geo-Transparent 数据同步允许您查看全局命名空间中的数据更改。

也可以仅传输元数据更改。启用后，用户可以构建可以按需加载数据更改的高效访问端点。


## 参考
[edgefs-storage](https://rook.io/docs/rook/v1.0/edgefs-storage.html)  
[开发者被 GitHub 要求下架开源项目仓库，因为其上游项目未“开源”](https://www.oschina.net/news/115501/recevied-an-dmca-takedown-from-github)  
[EdgeFS概要まとめ](https://techstep.hatenablog.com/entry/2020/02/12/083821)
[Nexenta_Replicast_White_Paper](file:///Users/xiefei/Desktop/Nexenta_Replicast_White_Paper.pdf)  
[Cloud Copy On Write (CCOW)](https://nexenta.com/solutions/openstack/cloud-copy-write-ccow)  
[Multi-Segment Distributed Storage for Kubernetes](https://medium.com/edgefs/multi-segment-distributed-storage-for-kubernetes-fd01e13887d1)    



