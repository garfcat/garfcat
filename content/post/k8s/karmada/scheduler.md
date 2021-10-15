---
title: "Karmada Scheduler核心实现" # Title of the blog post.
date: 2021-10-15T11:47:48+08:00 # Date of post creation.
description: "Article description." # Description used for search engine.
featured: true # Sets if post is a featured post, making appear on the home page side bar.
draft: true # Sets whether to render this page. Draft of true will not be rendered.
toc: true # Controls if a table of contents should be generated for first-level links automatically.
# menu: main
featureImage: "/images/path/file.jpg" # Sets featured image on blog post.
thumbnail: "/images/path/thumbnail.png" # Sets thumbnail image appearing inside card on homepage.
shareImage: "/images/path/share.png" # Designate a separate image for social media sharing.
codeMaxLines: 10 # Override global value for how many lines within a code block before auto-collapsing.
codeLineNumbers: false # Override global value for showing of line numbers within code block.
figurePositionShow: true # Override global value for showing the figure label.
categories:
  - Technology
tags:
  - Tag_name1
  - Tag_name2
# comment: false # Disable comment if false.
---
Karmada(Kubernetes Armada) 是一个多集群管理系统，在原生 Kubernetes 的基础上增加对于多集群应用资源编排控制的API和组件，从而实现多集群的高级调度，本文就详细分析一下 karmada 层面多集群调度的具体实现逻辑。
Karmada Scheduler（ Karmada 调度组件）主要是负责处理添加到队列中的 ResourceBinding 资源，通过内置的调度算法为资源选出一个或者多个合适的集群以及 replica 数量。

**注意：** 本文使用 karmada 版本为 tag:v0.8.0 commit: c37bedc1

## 调度框架
![karmada scheduler arch](/static/k8s/karmada/arch.png)

karmada-scheduler 在启动过程中实例化并运行了多个资源的 Informer（如图所示有bindingInformer, policyInformer,clusterBindingInformer, clusterPolicyInformer, memberClusterInformer）。    
bindingInformer, clusterBindingInformer 是直接监听binding/clusterBinding 的Add/Update事件存储到调度队列；  
policyInformer/clusterPolicyInformer 是用来监听 policy/clusterPolicy 的Update事件，将关联的 binding/clusterBinding 添加到调度队列；  
memberClusterInformer 将监控到的 cluster 资源存储到调度缓存中。  
- 调度队列： 存储了待处理的 binding/clusterBinding 事件，使用的是先进先出队列。    
- 调度缓存： 缓存了 cluster 的信息。    

需要根据 binding/clusterBinding 当前状态决定下一步如何处理，共有如下几个状态，以 binding 为例: 
 
- 首次调度(FirstSchedule):   resourceBinding 对象中的 spec.Clusters 字段为空，即从未被调度过。  
- 调协调度(ReconcileSchedule)： policy 的 placement 发生变化时就需要进行调协调度。 
- 扩缩容调度(ScaleSchedule):  policy ReplicaSchedulingStrategy 中 replica 与实际运行的不一致时就需需要进行扩缩容调度。  
- 故障恢复调度(FailoverSchedule):  调度结果集合中 cluster 的状态如果有未就绪的就需要进行故障恢复调度。
- 无需调度(AvoidSchedule):  默认行为，上面四个调度都未执行，则不进行任何调度。

## 首次调度（FirstSchedule）
主要通过 scheduleOne 函数来实现，分为三个步骤：  
1. 根据 namespace 和 name 查询出 resource binding;  
2. 通过 genericScheduler.Schedule 执行 预选算法 优选算法选择出合适的 集群集合;  
3. 如果选择出合适的集群集合，赋值给 binding (spec.Clusters);  

### 预选算法
通过 findClustersThatFit 找到符合基本条件的集群;  
代码路径 pkg/scheduler/core/generic_scheduler.go  
```golang
// findClustersThatFit finds the clusters that are fit for the placement based on running the filter plugins.
func (g *genericScheduler) findClustersThatFit(
	ctx context.Context,
	fwk framework.Framework,
	placement *policyv1alpha1.Placement,
	resource *workv1alpha1.ObjectReference,
	clusterInfo *cache.Snapshot) ([]*clusterv1alpha1.Cluster, error) {
	var out []*clusterv1alpha1.Cluster
	clusters := clusterInfo.GetReadyClusters()
	for _, c := range clusters {
		resMap := fwk.RunFilterPlugins(ctx, placement, resource, c.Cluster())
		res := resMap.Merge()
		if !res.IsSuccess() {
			klog.V(4).Infof("cluster %q is not fit", c.Cluster().Name)
		} else {
			out = append(out, c.Cluster())
		}
	}

	return out, nil
}
```
通过 RunFilterPlugins 执行 filter 的扩展函数从而过滤掉不符合条件的集群， 扩展点包含三个插件：
1. clusteraffinity:  集群亲缘性过滤，通过 ExcludeClusters 可以明确排除某些集群， 也可以通过 LabelSelector FieldSelector 进行匹配，也可以直接通过 cluster name 进行匹配；  
2. tainttoleration:  污点容忍性，过滤掉带有 tanit 但是 无法容忍的集群；
3. apiinstalled:  检查资源的 API 是否已经安装，过滤掉未安装API的集群；
经过以上三步之后可以得到初步满足需求的集群集合。   