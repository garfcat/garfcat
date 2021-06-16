---
title: "kubernetes 架构"
date: 2019-10-31T15:26:32+08:00
tags: ["kubernetes", "kubernetes arch"]
series: ["kubernetes"]
categories: ["kubernetes"]
---
# 什么是 Kubernetes
Kubernetes(简称K8s) 是由 Google 在2014年开源的容器编排与调度管理框架，主要是为用户提供一个具有普遍意义的容器编排工具。该项目是Google内部大规模集群管理系统-Borg的一个开源版本，目前是由CNCF(Cloud Native Computing Foundation)托管项目。
Kubernetes 的主要特点：  
1. 可扩展：Kubernetes 是高度可配置且可扩展的。
2. 可移植：Kubernetes 不限于特定平台，可以在各种公共或者私有云平台上运行。
3. 自动化：Kubernetes 是一个高度自动化的平台：可自动部署/回滚、自我修复、自动扩缩容。

# Kubernetes 架构
K8s 遵循服务器/客户端(C/S)架构,分为两部分master和node，其中master是服务端，是控制节点主要控制和管理整个K8s集群;node是客户端,是工作节点，主要处理来自于master的任务。K8s可以设置多master来实现高可用，但是默认情况下单个master 就可以完成所有的工作。  
master包含的组件有：kube-apiserver, etcd, kube-controller-manager, kube-scheduler, cloud-controller-manager;    
node 包含的组件有: kubelet, kube-proxy;  
![带有两个Worker nodes和一个master的K8s架构图](https://raw.githubusercontent.com/garfcat/garfcat/master/static/k8s/Kubernetes-101-Architecture-Diagram-768x555.jpeg)
[图片来源](https://x-team.com/blog/introduction-kubernetes-architecture/)

## master 组件
kube-apiserver: 提供集群HTTP REST API, 是集群控制的唯一入口,提供访问控制、注册、信息存储功能, 同时也是集群内部模块之间数据交换的枢纽。    
etcd:  兼具一致性和高可用性的键值数据库,保存 K8s 所有集群数据;  
kube-scheduler:  对K8s中的Pod资源进行监控调度，为Pod选择合适的工作节点；    
kube-controller-manager: K8s实现自动化的关键组件，是集群中所有资源的自动化控制中心；  
cloud-controller-manager: 云控制器管理器是指嵌入特定云的控制逻辑的控制平面组件,使得 K8s 可以直接利用云平台实现持久化卷、负载均衡、网络路由、DNS 解析以及横向扩展等功能。    
 
## node 组件
kubelet: 负责与master节点通信，处理master下发的任务，管理节点上容器的创建、停止与删除等;    
kube-proxy: 负责K8s集群服务的通信以及负载均衡；

# 数据流转




# 参考
[Kubernetes Architecture](https://www.aquasec.com/cloud-native-academy/kubernetes-101/kubernetes-architecture/)  
[INTRODUCTION TO KUBERNETES ARCHITECTURE](https://x-team.com/blog/introduction-kubernetes-architecture/)  
[服务](https://kubernetes.io/zh/docs/concepts/services-networking/service/)  
[Kubernetes的三种外部访问方式：NodePort、LoadBalancer 和 Ingress](http://dockone.io/article/4884)  
[极客时间]()