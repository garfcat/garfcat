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
K8s 遵循服务器/客户端(C/S)架构,分为两部分master和node，其中master是服务端,node是客户端。K8s可以设置多Master来实现高可用，但是默认情况下单个master 就可以完成所有的工作。
master包含的组件有：kube-apiserver, etcd, kube-controller-manager, kube-scheduler;  
node 包含的组件有: kubelet,  kube-proxy;




# 参考
[Kubernetes Architecture](https://www.aquasec.com/cloud-native-academy/kubernetes-101/kubernetes-architecture/)  
[INTRODUCTION TO KUBERNETES ARCHITECTURE](https://x-team.com/blog/introduction-kubernetes-architecture/)  
[服务](https://kubernetes.io/zh/docs/concepts/services-networking/service/)  
[Kubernetes的三种外部访问方式：NodePort、LoadBalancer 和 Ingress](http://dockone.io/article/4884)  
[极客时间]()