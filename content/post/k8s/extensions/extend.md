---
title: "Kubernetes 扩展"
date: 2021-06-08T16:18:40+08:00
---

Kubernetes 是Google开源的容器编排项目，是云原生时代最成功的项目之一，其本身也是高度可配置且可扩展的，这就可以让我们利用扩展开发出符合我们业务逻辑的软件，本文就其扩展展开讨论。
# Kubernetes 扩展点
Kubernetes 在官网给出了7个扩展点：
1. Kubectl扩展: 以 kubectl- 开头的可执行文件，需要注意两点：
    * 变量传递：所有环境变量也按原样传递给可执行文件；
    * 命令最长匹配：插件机制总是为给定的用户命令选择尽可能长的插件名称;
    * 影响范围： 只对本地环境造成影响；
2. API访问扩展：请求到达API服务时都会经过：认证、鉴权、准入控制这几个阶段，API访问扩展就是对这几个阶段进行扩展,使用户可以对请求执行身份认证、基于其内容阻止请求、编辑请求内容、处理删除操作等等。
3. 自定义资源：Kubernetes 内部有很多内置资源：Pods、Services、Deployments等等，这些资源有时满足不了我们的实际需求，此时我们可以定义满足业务需求的资源（CRD），自定义资源一般与自定义控制器结合使用。
4. 调度器扩展：Kubernetes 调度器负责决定 Pod 要放置到哪些节点上执行，我们可以通过实现调度器扩展来实现我们自己的调度策略。
5. 控制器扩展：一般与自定义资源结合使用，成为 **Operator 模式**。
6. 网络插件：用来扩展 Pod 网络的插件。
7. 存储插件：用来扩展存储的插件。

# Operator 模式
自定义资源和控制器组成了 Operator 模式。在该模式下可以让你自动化完成应用部署、管理。  
在 Kubernetes 中，Operator 是一个软件扩展，它利用自定义资源来管理应用程序及其组件。Operator 是 Kubernetes API 的客户端，用于控制自定义资源。Operator 是特定于应用程序的控制器，用于管理自定义资源的状态。
>使用 Operator 可以自动化的事情包括：
> * 按需部署应用
> * 获取/还原应用状态的备份
> * 处理应用代码的升级以及相关改动。例如，数据库 schema 或额外的配置设置
> * 发布一个 service，要求不支持 Kubernetes API 的应用也能发现它
> * 模拟整个或部分集群中的故障以测试其稳定性
> * 在没有内部成员选举程序的情况下，为分布式应用选择首领角色

# 控制器 Reconcile loop
控制器与资源关联，并监听资源的变化，如果资源发生变化，则会进入一个循环即调协循环(Reconcile loop)，伪代码如下：
```golang
for {
  expectState := GetExpectState()
  actualState := GetActualState()
  if expectState == actualState {
    // do nothing
  } else {
    // adjust the state to the expect state
  }
}
```
调协循环(Reconcile loop) 是通过事件驱动和定时执行来实现，不断对比实际状态与期望状态，并不断调整实际状态向实际状态靠拢。

# 总结
Kubernetes 提供了7个扩展点, 其中自定义资源和控制器组成了 Operator 模式，Operator 的工作原理,实际上是利用了 Kubernetes 的自定义 API 资源(CRD),来描述我们想要部署的“有状态应用”;然后在自定义控制器里,根据自定义 API 对象的变化,来完成具体的部署和运维工作。其中控制的调协循环更是编排的核心。

# 参考

[Extending Kubernetes — Part 1 — Custom Operator](https://krvarma.medium.com/extending-kubernetes-part-1-custom-operator-b6745c42be4f)  
[扩展 Kubernetes](https://kubernetes.io/zh/docs/concepts/extend-kubernetes/#user-defined-types)