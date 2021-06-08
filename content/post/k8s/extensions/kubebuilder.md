---
title: "Kubebuilder 使用教程"
date: 2021-06-08T16:18:16+08:00
tags: [ "kubebuilder", "kubernetes" , "extend"]
series: ["kubernetes extend"]
categories: ["kubernetes extend"]
---

# Kubebuilder 是什么
kubebuilder 是使用自定义资源（CRD）构建 Kubernetes API 的框架。Kubebuilder提高了开发人员在Go中快速构建和发布Kubernetes api的速度，降低了开发管理的复杂性。

# Kubebuilder 如何使用
我们通过向 Kubernetes 集群添加一个自定义 Cluster 来了解 Kubebuilder 如何使用。
其主要步骤如下：  
1. 创建一个项目  
2. 创建一个API  
3. 定义CRD
4. 实现controller
5. 测试

## 创建项目

 1. 创建目录ipes-cmp 并进入执行 go mod init ipes-cmp 来告诉 kubebuilder 和 Go module 的基本导入路径。
 2. 执行 kubebuilder init 命令，初始化一个新项目。示例如下。
    kubebuilder init --domain ipes-cmp

    **--domain**: 项目的域名
    
## 创建一个API
运行下面的命令，创建一个新的 API（组/版本）为 “cluster/v1”，并在上面创建新的 Kind(CRD) “Cluster”。
```sbtshell
   kubebuilder create api --group cluster --version v1 --kind Cluster
```
目录结构：
```sbtshell

在 Create Resource [y/n] 和 Create Controller [y/n] 中按y，创建文件 api/v1/cluster_types.go ，
该文件中定义相关 API ，而针对于这一类型 (CRD) 的对账业务逻辑生成在 controller/cluster_controller.go 文件中。
.
├── Dockerfile
├── Makefile       # 这里定义了很多脚本命令，例如运行测试，开始执行等
├── PROJECT    # 这里是 kubebuilder 的一些元数据信息
├── api
│   └── v1
│       ├── cluster_types.go   #定义 Spec 和 Status
│       ├── groupversion_info.go  # 包含了关于 group-version 的一些元数据
│       └── zz_generated.deepcopy.go
├── bin
│   └── controller-gen
├── config
│   ├── crd   # 部署 crd 所需的 yaml, 自动生成, 只需要修改了 v1 中的 go 文件之后执行 make generate 即可
│   │   ├── kustomization.yaml
│   │   ├── kustomizeconfig.yaml
│   │   └── patches
│   │       ├── cainjection_in_clusters.yaml
│   │       └── webhook_in_clusters.yaml
│   ├── default     # 一些默认配置
│   │   ├── kustomization.yaml
│   │   ├── manager_auth_proxy_patch.yaml
│   │   └── manager_config_patch.yaml
│   ├── manager
│   │   ├── controller_manager_config.yaml
│   │   ├── kustomization.yaml
│   │   └── manager.yaml
│   ├── prometheus   # 监控指标数据采集配置
│   │   ├── kustomization.yaml
│   │   └── monitor.yaml
│   ├── rbac   # 部署所需的 rbac 授权 yaml
│   │   ├── auth_proxy_client_clusterrole.yaml
│   │   ├── auth_proxy_role.yaml
│   │   ├── auth_proxy_role_binding.yaml
│   │   ├── auth_proxy_service.yaml
│   │   ├── cluster_editor_role.yaml
│   │   ├── cluster_viewer_role.yaml
│   │   ├── kustomization.yaml
│   │   ├── leader_election_role.yaml
│   │   ├── leader_election_role_binding.yaml
│   │   ├── role_binding.yaml
│   │   └── service_account.yaml
│   └── samples  # 这里是 crd 示例文件，可以用来部署到集群当中
│       └── cluster_v1_cluster.yaml
├── controllers
│   ├── cluster_controller.go
│   └── suite_test.go
├── go.mod
├── go.sum
├── hack
│   └── boilerplate.go.txt
└── main.go
```

## 定义CRD
修改 cluster_type.go 文件添加地域信息：
```golang 
// ClusterSpec defines the desired state of Cluster
type ClusterSpec struct {
	// INSERT ADDITIONAL SPEC FIELDS - desired state of cluster
	// Important: Run "make" to regenerate code after modifying this file

	// Foo is an example field of Cluster. Edit cluster_types.go to remove/update
	Foo string `json:"foo,omitempty"`

	// Region represents the region of the member cluster locate in.
	// +optional
	Region string `json:"region,omitempty"`
}
```
修改完之后执行 make manifests generate ，可以生成对应的config/bases/cluster.ipes.io_clusters.yaml文件。可以看到spec信息如下：
```sbtshell
  spec:
    description: ClusterSpec defines the desired state of Cluster
    properties:
      foo:
        description: Foo is an example field of Cluster. Edit cluster_types.go
          to remove/update
        type: string
      region:
        description: Region represents the region of the member cluster locate
          in.
        type: string
    type: object
```

# 实现controller
controller的逻辑框架kubebuilder已经帮我们完成，我们只需要完成最核心的函数 *Reconcile*即可；
```golang
#controllers/cluser_controller.go
func (r *ClusterReconciler) Reconcile(ctx context.Context, req ctrl.Request) (ctrl.Result, error) {
	_ = r.Log.WithValues("cluster", req.NamespacedName)

	r.

	return ctrl.Result{}, nil
}
```
在这里我们获取cluster信息并打印
```golang
func (r *ClusterReconciler) Reconcile(ctx context.Context, req ctrl.Request) (ctrl.Result, error) {
	_ = r.Log.WithValues("cluster", req.NamespacedName)

	cluster := &clusterv1.Cluster{}
	if err := r.Client.Get(context.TODO(), req.NamespacedName, cluster); err != nil {
		// The resource may no longer exist, in which case we stop processing.
		if apierrors.IsNotFound(err) {
			return ctrl.Result{}, nil
		}
		return ctrl.Result{Requeue: true}, err
	}
	// your logic here
	r.Log.Info("ipes cluster status change", "name", cluster.Name, "region", cluster.Spec.Region)
	return ctrl.Result{}, nil
}
```

## 测试
### 部署CRD资源
我们在实现了controller 的核心逻辑之后， 需要先将CRD注册到集群中, 具体命令：
```sbtshell
make install
```
这里make install ; 是执行了以下两步：
1. make manifests  # 生成CRD资源
2. bin/kustomize build config/crd | kubectl apply -f - #生成部署CRD， 并部署到集群中
如果集群不在本地， 可以分开执行这两步。

### 运行 controller
本地直接执行 make run 即可，我这里需要编译后，放到服务器上执行：
```sbtshell
➜  ~ ./ipes-cmp
2021-06-08T19:22:38.187+0800	INFO	controller-runtime.metrics	metrics server is starting to listen	{"addr": ":8080"}
2021-06-08T19:22:38.188+0800	INFO	setup	starting manager
2021-06-08T19:22:38.188+0800	INFO	controller-runtime.manager	starting metrics server	{"path": "/metrics"}
2021-06-08T19:22:38.188+0800	INFO	controller-runtime.manager.controller.cluster	Starting EventSource	{"reconciler group": "cluster.ipes.io", "reconciler kind": "Cluster", "source": "kind source: /, Kind="}
2021-06-08T19:22:38.289+0800	INFO	controller-runtime.manager.controller.cluster	Starting Controller	{"reconciler group": "cluster.ipes.io", "reconciler kind": "Cluster"}
2021-06-08T19:22:38.289+0800	INFO	controller-runtime.manager.controller.cluster	Starting workers	{"reconciler group": "cluster.ipes.io", "reconciler kind": "Cluster", "worker count": 1}
```

### 添加一个测试例子
创建一个测试的集群
```yaml
apiVersion: cluster.ipes.io/v1
kind: Cluster
metadata:
  name: test-cluster
spec:
  # Add fields here
  region: beijing
```
```sbtshell
kubectl apply -f bj_cluster.yml # 部署测试集群
```

可以看到controller 输入日志，controller已经获取到关于cluster的信息。
```yaml
2021-06-08T19:35:49.562+0800	INFO	controllers.Cluster	ipes cluster status change	{"name": "test-cluster", "region": "beijing"}
```

# 总结
>目前扩展 Kubernetes 的 API 的方式有创建 CRD、使用 Operator SDK 等方式，都需要写很多的样本文件（boilerplate），使用起来十分麻烦。为了能够更方便构建 Kubernetes API 和工具，就需要一款能够事半功倍的工具，与其他 Kubernetes API 扩展方案相比，kubebuilder 更加简单易用，并获得了社区的广泛支持。



 
# 参考
[深入解析 Kubebuilder：让编写 CRD 变得更简单](https://developer.aliyun.com/article/719215)  
[Kubebuilder](https://cloudnative.to/kubebuilder/quick-start.html)   
[Kubernetes中文指南/云原生应用架构实践手册(201910)](https://www.bookstack.cn/read/kubernetes-handbook-201910/develop-kubebuilder.md)