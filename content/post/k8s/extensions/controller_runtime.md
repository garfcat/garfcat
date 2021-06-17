---
title: "kKubernetes Controller runtime 详解" # Title of the blog post.
date: 2021-06-17T13:40:20+08:00 # Date of post creation.
tags: [ "kubebuilder", "kubernetes" , "controller runtime"]
series: ["kubernetes extend"]
categories: ["kubernetes extend"]
---
controller-runtime(https://github.com/kubernetes-sigs/controller-runtime) 框架是社区封装的一个控制器处理的框架，Kubebuilder、Operator-sdk 这两个框架也是基于controller-runtime做了一层封装，目的是快速生成operator项目代码。下面我们就来具体分析一下下 controller-runtime 原理以及实现 。
# 概念
- CRD:
  自定义资源(CustomResourceDefinition), K8s允许你定义自己的定制资源，K8s API 负责为你的定制资源提供存储和访问服务。   
  下面例子是定义了一个crontab 的自定义资源:   
  ```yaml
    apiVersion: apiextensions.k8s.io/v1
    kind: CustomResourceDefinition
    metadata:
      # 名字必需与下面的 spec 字段匹配，并且格式为 '<名称的复数形式>.<组名>'
      name: crontabs.stable.example.com
    spec:
      # 组名称，用于 REST API: /apis/<组>/<版本>
      group: stable.example.com
      # 列举此 CustomResourceDefinition 所支持的版本
      versions:
        - name: v1
          # 每个版本都可以通过 served 标志来独立启用或禁止
          served: true
          # 其中一个且只有一个版本必需被标记为存储版本
          storage: true
          schema:
            openAPIV3Schema:
              type: object
              properties:
                spec:
                  type: object
                  properties:
                    cronSpec:
                      type: string
                    image:
                      type: string
                    replicas:
                      type: integer
      # 可以是 Namespaced 或 Cluster
      scope: Namespaced
      names:
        # 名称的复数形式，用于 URL：/apis/<组>/<版本>/<名称的复数形式>
        plural: crontabs
        # 名称的单数形式，作为命令行使用时和显示时的别名
        singular: crontab
        # kind 通常是单数形式的驼峰编码（CamelCased）形式。你的资源清单会使用这一形式。
        kind: CronTab
        # shortNames 允许你在命令行使用较短的字符串来匹配资源
        shortNames:
        - ct
  ```  
- GVK GVR: GVK是 Group Version Kind 的缩写，GVR 是 Group Version Resource 的缩写  
   Group: ApiGroup,是相关API功能的集合。  
   Version: ApiGroup的版本， 每个ApiGroup可以对应多个版本。  
   Kind：资源类型。
   Resource：资源，Kind的具象化，类似于面向对象语言中的类与对象，Kind就是类，Resource就是对象。  
    
  那么在创建 CRD 后，我们如何向 K8s 创建具体资源呢？我们只需要定义一个 yaml 文件，里面指明 GVK 就可以了，如下所示：
  ```yaml
    # group/version: group 是 stable.example.com， version 是 v1
    apiVersion: "stable.example.com/v1" 
    kind: CronTab  
    metadata:
      name: my-new-cron-object
    spec:
      cronSpec: "* * * * */5"
      image: my-awesome-cron-image
  ```
    
- Schema: 定义了资源序列化和反序列化的方法以及资源类型和版本的对应关系,可以根据GVK找到Go Type, 也可以通过Go Type找到GVK。
- Informer机制  
Kubernetes的其他组件都是通过client-go(K8s系统使用client-go作为Go语言的官方编程式交互客户端库,提供对 K8s API Server服务的交互访问)的Informer机制与Kubernetes API Server进行通信的。  
- Clients
  提供访问API对象的客户端。
- Caches
  默认情况下客户端从本地缓存读取对象。缓存将自动缓存需要Watch的对象，同时也会缓存其他被请求的结构化对象。Cache内部是通过Informer负责监听对应 GVK 的 GVR 的创建/删除/更新操作,然后通知所有 Watch 该 GVK 的 Controller, Controller 将对应的资源名称添加到 Queue 里面,最终触发 Reconciler 的调协。
- Managers  
 Controller runtime抽象的最外层的管理对象，负责管理 Controller、Caches、Client，以及 leader 选举。
- Controllers  
 控制器响应事件(Create/Update/Delete)来触发调协(reconcile)请求,与要实现的调协逻辑一一对应，会创建限速Queue, 一个 Controller 可以关注很多 GVK,然后根据 GVK 到 Cache 里面找到对应的 Share Informer 去 Watch 资源,Watch 到的事件会加入到 Queue里面, Queue 最终触发开发者的 Reconciler 的调和。
- Reconcilers  
开发者主要实现的逻辑，用来接收Controller的GVK事件，然后获取GVR 进行协调并决定是否更新或者重新入队。

# 整体设计
Controller-runtime设计图如下所示：
![](https://raw.githubusercontent.com/garfcat/garfcat/master/static/k8s/controller_runtime.jpg)
controller 的整理流程：
1. 首先会初始化Schema, 注册原生资源以及自定义资源;
2. 创建并初始化manager，将schema传入，并在内部初始化cache和client等其他资源;
3. 创建并初始化 Reconciler, 传入 client 和 schema
4. 将 Reconciler 注册到 manager，并创建controller 与 Reconciler 绑定;
5. Controller Watch 自定义资源，此时 controller 会从 Cache 里面去获取 Share Informer,如果没有则创建,然后对该 Share Informer 进行 Watch,将得到的资源的名字和 Namespace存入到Queue中；
6. Controller 不断获取 Queue 中的数据并调用 Reconciler 进行调协；



# 参考文献
[1. 定制资源](https://kubernetes.io/zh/docs/concepts/extend-kubernetes/api-extension/custom-resources/)  
[2. controller-runtime 之控制器实现](https://jishuin.proginn.com/p/763bfbd2f5b9)  
[3. 还在手写 Operator?是时候使用 Kubebuilder 了](https://my.oschina.net/u/4657223/blog/4792083)  