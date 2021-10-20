---
title: "Karmada Scheduler核心实现" # Title of the blog post.
date: 2021-10-15T11:47:48+08:00 # Date of post creation.
description: "Article description." # Description used for search engine.
featured: true # Sets if post is a featured post, making appear on the home page side bar.
draft: false # Sets whether to render this page. Draft of true will not be rendered.
toc: true # Controls if a table of contents should be generated for first-level links automatically.
# menu: main
featureImage: "/static/images/cat.png" # Sets featured image on blog post.
thumbnail: "/static/images/cat.png" # Sets thumbnail image appearing inside card on homepage.
shareImage: "/images/path/share.png" # Designate a separate image for social media sharing.
codeMaxLines: 10 # Override global value for how many lines within a code block before auto-collapsing.
codeLineNumbers: true # Override global value for showing of line numbers within code block.
figurePositionShow: true # Override global value for showing the figure label.
categories:
  - karmada
tags:
  - karmada
  - cmp
# comment: false # Disable comment if false.
---
Karmada(Kubernetes Armada) 是一个多集群管理系统，在原生 Kubernetes 的基础上增加对于多集群应用资源编排控制的API和组件，从而实现多集群的高级调度，本文就详细分析一下 karmada 层面多集群调度的具体实现逻辑。
Karmada Scheduler（ Karmada 调度组件）主要是负责处理添加到队列中的 ResourceBinding 资源，通过内置的调度算法为资源选出一个或者多个合适的集群以及 replica 数量。

**注意：** 本文使用 karmada 版本为 tag:v0.8.0 commit: c37bedc1

## 调度框架
![karmada scheduler arch](/static/k8s/karmada/scheduler.png)

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

### 优选调度过程
通过 **预选调度** 我们已经得到基本满足需求的集群集合，优选调度过程主要是通过策略给每个集群进行打分， 但是目前所有插件未实现具体逻辑，都简单返回0。 插件与预选过程是一样的，都是这以下三个插件：clusteraffinity、tainttoleration、apiinstalled。


### 选择集群过程
通过 **预选调度** 、 **优选调度** 我们可以得出符合条件的集群集合以及每个集群的得分(得分未实现)，选择集群过程是通过 SpreadConstraint 定义的字段将集群划分成不同的组，尽量将资源分发到不同的组，从而实现高可用。
选择集群分为两步：  
1. 将集群按照类型划分成不同的组；  
2. 从不同的组中选择出合适的集群；  

#### 划分不同的组
SpreadConstraint 的类型有： cluster、region、zone、provider, 目前只支持 cluster。

```golang

func (g *genericScheduler) selectClusters(clustersScore framework.ClusterScoreList, spreadConstraints []policyv1alpha1.SpreadConstraint, clusters []*clusterv1alpha1.Cluster) []*clusterv1alpha1.Cluster {
	if len(spreadConstraints) != 0 {
		return g.matchSpreadConstraints(clusters, spreadConstraints)
	}

	return clusters
}
func (g *genericScheduler) matchSpreadConstraints(clusters []*clusterv1alpha1.Cluster, spreadConstraints []policyv1alpha1.SpreadConstraint) []*clusterv1alpha1.Cluster {
	state := util.NewSpreadGroup()
	g.runSpreadConstraintsFilter(clusters, spreadConstraints, state)
	return g.calSpreadResult(state)
}

// Now support spread by cluster. More rules will be implemented later.
func (g *genericScheduler) runSpreadConstraintsFilter(clusters []*clusterv1alpha1.Cluster, spreadConstraints []policyv1alpha1.SpreadConstraint, spreadGroup *util.SpreadGroup) {
	for _, spreadConstraint := range spreadConstraints {
		spreadGroup.InitialGroupRecord(spreadConstraint)
		if spreadConstraint.SpreadByField == policyv1alpha1.SpreadByFieldCluster {
			g.groupByFieldCluster(clusters, spreadConstraint, spreadGroup)
		}
	}
}

func (g *genericScheduler) groupByFieldCluster(clusters []*clusterv1alpha1.Cluster, spreadConstraint policyv1alpha1.SpreadConstraint, spreadGroup *util.SpreadGroup) {
	for _, cluster := range clusters {
		clusterGroup := cluster.Name
		spreadGroup.GroupRecord[spreadConstraint][clusterGroup] = append(spreadGroup.GroupRecord[spreadConstraint][clusterGroup], cluster)
	}
}

```

#### 从不同的组选择出集群

```golang
func (g *genericScheduler) chooseSpreadGroup(spreadGroup *util.SpreadGroup) []*clusterv1alpha1.Cluster {
	var feasibleClusters []*clusterv1alpha1.Cluster
	for spreadConstraint, clusterGroups := range spreadGroup.GroupRecord {
        //  目前支持cluster name 进行的分组
		if spreadConstraint.SpreadByField == policyv1alpha1.SpreadByFieldCluster {
            // 如果小于最小组的数量，则返回nil
			if len(clusterGroups) < spreadConstraint.MinGroups {
				return nil
			}
            // 如果划分的组数 在最小-最大之间， 则将所有集群添加的结果集合
			if len(clusterGroups) <= spreadConstraint.MaxGroups {
				for _, v := range clusterGroups {
					feasibleClusters = append(feasibleClusters, v...)
				}
				break
			}
            // 如果划分的组大于限制的最大组数，则将分组数限制为 MaxGroups
			if spreadConstraint.MaxGroups > 0 && len(clusterGroups) > spreadConstraint.MaxGroups {
				var groups []string
				for group := range clusterGroups {
					groups = append(groups, group)
				}

				for i := 0; i < spreadConstraint.MaxGroups; i++ {
					feasibleClusters = append(feasibleClusters, clusterGroups[groups[i]]...)
				}
			}
		}
	}
	return feasibleClusters
}

```

### 为选择的集群分配Replicas  

为选择的集群分配Replicas，是通过 **assignReplicas** 方法实现，该方法是根据 replicaSchedulingStrategy（在 propagation policy中定义 placement时,同时指定replica scheduling strategy） 策略进行分配。

```golang
func (g *genericScheduler) assignReplicas(clusters []*clusterv1alpha1.Cluster, replicaSchedulingStrategy *policyv1alpha1.ReplicaSchedulingStrategy, object *workv1alpha1.ObjectReference) ([]workv1alpha1.TargetCluster, error) {
	if len(clusters) == 0 {
		return nil, fmt.Errorf("no clusters available to schedule")
	}
	targetClusters := make([]workv1alpha1.TargetCluster, len(clusters))

	if object.Replicas > 0 && replicaSchedulingStrategy != nil {
		if replicaSchedulingStrategy.ReplicaSchedulingType == policyv1alpha1.ReplicaSchedulingTypeDuplicated {
			for i, cluster := range clusters {
				targetClusters[i] = workv1alpha1.TargetCluster{Name: cluster.Name, Replicas: object.Replicas}
			}
			return targetClusters, nil
		}
		if replicaSchedulingStrategy.ReplicaSchedulingType == policyv1alpha1.ReplicaSchedulingTypeDivided {
			if replicaSchedulingStrategy.ReplicaDivisionPreference == policyv1alpha1.ReplicaDivisionPreferenceWeighted {
				if replicaSchedulingStrategy.WeightPreference == nil {
					return nil, fmt.Errorf("no WeightPreference find to divide replicas")
				}
				return g.divideReplicasByStaticWeight(clusters, replicaSchedulingStrategy.WeightPreference.StaticWeightList, object.Replicas)
			}
			if replicaSchedulingStrategy.ReplicaDivisionPreference == policyv1alpha1.ReplicaDivisionPreferenceAggregated {
				return g.divideReplicasAggregatedWithResource(clusters, object)
			}
			return g.divideReplicasAggregatedWithResource(clusters, object) //default policy for ReplicaSchedulingTypeDivided
		}
	}

	for i, cluster := range clusters {
		targetClusters[i] = workv1alpha1.TargetCluster{Name: cluster.Name}
	}
	return targetClusters, nil
}
```
replica scheduler 支持两种类型的调度：  
1. 复制(ReplicaSchedulingTypeDuplicated): 不对 deployment 中的replica 数量做修改，直接复制到各个子集群；  
2. 切分(ReplicaSchedulingTypeDivided): 将 deployment 中定义的 replica数量，按照策略进行切分，然后分发到不同的子集群，目前支持的切分策略有： 权重（ReplicaDivisionPreferenceWeighted）、子集群资源(ReplicaDivisionPreferenceAggregated);  

复制类型的调度很简单此处不展开介绍，我们重点介绍切分的不同策略：  
##### 按照权重进行切分
下面是按照权重划分的 策略定义， 特别注意的是，如果按照权重划分之后还有未分配的replica, 剩余的 replica 会按照顺序分配到各个集群（集群按照权重排序）上。
```yaml
apiVersion: policy.karmada.io/v1alpha1
kind: ReplicaSchedulingPolicy
metadata:
  name: foo
  namespace: foons
spec:
  resourceSelectors:
    - apiVersion: apps/v1
      kind: Deployment
      namespace: foons
      name: deployment-1
  totalReplicas: 100
  preferences:
    staticWeightList:
      - targetCluster:
          clusterNames: [cluster1]
        weight: 1
      - targetCluster:
          clusterNames: [cluster2]
        weight: 2
```

##### 按照子集群资源进行分配
如果 deployment 中资源的请求则按照子集群资源的使用情况进行分配，其核心逻辑如下所示：
1. 计算每个子集群最大可以分配的replica;   
2. 按照比例分配replica;  

###### 计算每个子集群最大可以分配的replica
```golang
func (g *genericScheduler) calClusterAvailableReplicas(cluster *clusterv1alpha1.Cluster, resourcePerReplicas corev1.ResourceList) int32 {
	var maximumReplicas int64 = math.MaxInt32
	resourceSummary := cluster.Status.ResourceSummary

	for key, value := range resourcePerReplicas {
		requestedQuantity := value.Value()
		if requestedQuantity <= 0 {
			continue
		}

		// calculates available resource quantity
		// available = allocatable - allocated - allocating
		allocatable, ok := resourceSummary.Allocatable[key]
		if !ok {
			return 0
		}
		allocated, ok := resourceSummary.Allocated[key]
		if ok {
			allocatable.Sub(allocated)
		}
		allocating, ok := resourceSummary.Allocating[key]
		if ok {
			allocatable.Sub(allocating)
		}
		availableQuantity := allocatable.Value()
		// short path: no more resource left.
		if availableQuantity <= 0 {
			return 0
		}

		if key == corev1.ResourceCPU {
			requestedQuantity = value.MilliValue()
			availableQuantity = allocatable.MilliValue()
		}

		maximumReplicasForResource := availableQuantity / requestedQuantity
		if maximumReplicasForResource < maximumReplicas {
			maximumReplicas = maximumReplicasForResource
		}
	}

	return int32(maximumReplicas)
}
```
1. 通过  available = allocatable - allocated - allocating 得到子集群目前可用资源；
2. 通过如下计算得到该集群最大的replica:
    ```golang
   		maximumReplicasForResource := availableQuantity / requestedQuantity
   		if maximumReplicasForResource < maximumReplicas {
   			maximumReplicas = maximumReplicasForResource
   		} 
   ```
######  按照比例分配replica
这块逻辑与权重分配类似，只不过这里的权重是 每个集群可以分配的最大replica.
其核心逻辑如下所示：
```golang
func (g *genericScheduler) divideReplicasAggregatedWithClusterReplicas(clusterAvailableReplicas []workv1alpha1.TargetCluster, replicas int32) ([]workv1alpha1.TargetCluster, error) {
	clustersNum := 0
	clustersMaxReplicas := int32(0)
	for _, clusterInfo := range clusterAvailableReplicas {
		clustersNum++
		clustersMaxReplicas += clusterInfo.Replicas
		if clustersMaxReplicas >= replicas {
			break
		}
	}
	if clustersMaxReplicas < replicas {
		return nil, fmt.Errorf("clusters resources are not enough to schedule, max %v replicas are support", clustersMaxReplicas)
	}

	desireReplicaInfos := make(map[string]int32)
	allocatedReplicas := int32(0)
	for i, clusterInfo := range clusterAvailableReplicas {
		if i >= clustersNum {
			desireReplicaInfos[clusterInfo.Name] = 0
			continue
		}
		desireReplicaInfos[clusterInfo.Name] = clusterInfo.Replicas * replicas / clustersMaxReplicas
		allocatedReplicas += desireReplicaInfos[clusterInfo.Name]
	}

	if remainReplicas := replicas - allocatedReplicas; remainReplicas > 0 {
		for i := 0; remainReplicas > 0; i++ {
			desireReplicaInfos[clusterAvailableReplicas[i].Name]++
			remainReplicas--
			if i == clustersNum {
				i = 0
			}
		}
	}

	targetClusters := make([]workv1alpha1.TargetCluster, len(clusterAvailableReplicas))
	i := 0
	for key, value := range desireReplicaInfos {
		targetClusters[i] = workv1alpha1.TargetCluster{Name: key, Replicas: value}
		i++
	}
	return targetClusters, nil
}
```

# 参考
《kubernetes 源码剖析》  