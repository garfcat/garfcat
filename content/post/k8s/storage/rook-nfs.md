---
title: "NFS 通过 rook 进行部署" # Title of the blog post.
date: 2021-09-13T20:39:50+08:00 # Date of post creation.
description: "rook nfs." # Description used for search engine.
featured: true # Sets if post is a featured post, making appear on the home page side bar.
draft: false # Sets whether to render this page. Draft of true will not be rendered.
toc: false # Controls if a table of contents should be generated for first-level links automatically.
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
  - NFS
  - rook
  - rook-nfs
# comment: false # Disable comment if false.
---

# 介绍


NFS是Network File System的简写，即网络文件系统，NFS是FreeBSD支持的文件系统中的一种。NFS基于RPC(Remote Procedure Call)远程过程调用实现，其允许一个系统在网络上与它人共享目录和文件。通过使用NFS，用户和程序就可以像访问本地文件一样访问远端系统上的文件。NFS是一个非常稳定的，可移植的网络文件系统。具备可扩展和高性能等特性，达到了企业级应用质量标准。由于网络速度的增加和延迟的降低，NFS系统一直是通过网络提供文件系统服务的有竞争力的选择 。




# NFS 使用方式
1. 已有NFS集群,例如公司QCE 申请的NFS集群, 在K8S中创建PVC和STorageClass ,一般通过 [Kubernetes NFS Subdir External Provisioner](https://github.com/kubernetes-sigs/nfs-subdir-external-provisioner) 创建动态的provisioner,然后就可以在集群中使用NFS服务了;


2.物理机上手动安装NFS集群, 通过linux命令进行安装, 然后可以按照 1 进行使用;


3.通过K8S进行安装, 安装方式有多种 NFS Provisioner 以及 rook 等, 通过k8s 管理nfs 集群, 然后对外提供服务;


此处主要介绍在 k8s 中安装nfs 服务并对集群内外提供服务.




# NFS 安装
## 主要步骤
- Step0: 创建Local Persistent Volume;  
- Step1: 创建StorageClass;
- Step2: 创建PVC, 关联 Step2 中的StorageClass;  
- Step3: 部署NFS Operator;  
- Step4: 创建NFS Server;
- Step5: 创建NFS Storage Class;
- Step6: 创建 Pod 并使用NFS;  
- Step7: 让集群外部服务也可以访问NFS Server;  




## Step0: 创建 Local Persistent Volume
首先在集群的宿主机(k8s-node2)创建挂载点, 比如 /mnt/disk; 然后 用RAM Disk 来模拟本地磁盘, 如下所示:
```shell
# 在 k8s-node2 上执行
$ mkdir /mnt/disks
$ for vol in vol1 vol2 vol3; do
      mkdir -p /mnt/disks/$vol
      mount -t tmpfs $vol /mnt/disks/$vol
   done

```
```
$ df 查看
vol3            7.8G     0  7.8G   0% /mnt/disks/vol3
vol1            7.8G     0  7.8G   0% /mnt/disks/vol1
vol2            7.8G     0  7.8G   0% /mnt/disks/vol2
```
注意: 其他机器如果也要创建 Local Persistent Volume, 那就执行相同的操作,但是磁盘名字不能重复.


接下来,定义PV, 如下所示:
```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: example-pv
spec:
  accessModes:
  - ReadWriteOnce
  capacity:
    storage: 5Gi
  local:
    path: /mnt/disks/vol1
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: In
          values:
          - k8s-node2
  persistentVolumeReclaimPolicy: Delete
  storageClassName: local-storage
  volumeMode: Filesystem


```
这个 PV 的定义里:local 字段,指定了它是一个 Local Persistent Volume; 而 path 字段,指定的正是这个 PV 对应的本地磁盘的路径,即:/mnt/disks/vol1。


接下来, 我们使用 kubectl create 来创建这个PV, 如下所示:
```shell
➜   kubectl get pv 
NAME                                       CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS      CLAIM                       STORAGECLASS      REASON   AGE
example-pv                                 5Gi        RWO            Delete           Available                               local-storage              6s
```
可以看到,example-pv创建后已经变成可用可用状态了.


## Step1: 创建StorageClass
通过StorageClass 描述 PV, 如下所示:
```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: local-storage
provisioner: kubernetes.io/no-provisioner
reclaimPolicy: Delete
volumeBindingMode: WaitForFirstConsumer
```
这里有两个重要的字段:
provisioner: 我们使用no-provisioner, 这是因为 Local Persistent Volume 目前尚不支持Dynamic Provisioning,所以它没办法在用户创建 PVC 的时候,就自动创建出对应的PV。
volumeBindingMode: WaitForFirstConsumer, 指定了延迟绑定.因为Local Persistent 需要等到调度时才可以进行绑定操作.
通过 kubectl create 来创建 StorageClass, 如下所示:
```shell
➜  kubectl create -f sc.yaml
storageclass.storage.k8s.io/local-storage created
➜  kubectl get sc
NAME              PROVISIONER                                     RECLAIMPOLICY   VOLUMEBINDINGMODE      ALLOWVOLUMEEXPANSION   AGE
local-storage     kubernetes.io/no-provisioner                    Delete          WaitForFirstConsumer   false                  25s
```




## Step2: 创建PVC
这里我们定义一个PVC来使用之前定义好的Local PV, 如下所示:

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: example-local-claim
  namespace: rook-nfs
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 5Gi
  storageClassName: local-storage
  volumeMode: Filesystem
  volumeName: example-pv
```

接下来创建这个PVC:
```shell
➜  kubectl create -f example-local-claim.yaml
persistentvolumeclaim/example-local-claim created
➜  kubectl get pvc -n rook-nfs
NAME                  STATUS   VOLUME       CAPACITY   ACCESS MODES   STORAGECLASS    AGE
example-local-claim   Bound    example-pv   5Gi        RWO            local-storage   25s


```
注意: 这里我们指定了namespace 为rook-nfs , 这是为了方便nfs operator 使用.


## Step3: 部署NFS Operator


安装 rook 之前需要先安装 NFS Client 安装包。在 CentOS 节点上安装 nf-utils，在 Ubuntu 节点上安装 nf-common。然后就可以安装 Rook 了。

```shell
$ git clone --single-branch --branch v1.7.3 https://github.com/rook/nfs.git
cd rook/cluster/examples/kubernetes/nfs
kubectl create -f crds.yaml
kubectl create -f operator.yaml

```

检查operator 是否运行正常:
```shell
➜   kubectl -n rook-nfs-system get pod
NAME                                READY   STATUS    RESTARTS   AGE
rook-nfs-operator-d489f8c4b-4hr9m   1/1     Running   0          33s
```

## Step4: 创建NFS Server
现在 operator 已经运行起来了,我们可以通过创建 nfsservers.nfs.rook.io 资源的实例来创建NFS服务器的实例,在这之前我们需要创建 ServiceAccount 和 RBAC规则:
```shell
➜  kubectl create -f rbac.yaml
namespace/rook-nfs created
serviceaccount/rook-nfs-server created
clusterrole.rbac.authorization.k8s.io/rook-nfs-provisioner-runner created
clusterrolebinding.rbac.authorization.k8s.io/rook-nfs-provisioner-runner created
```
接下来 将以下内容保存到nfs.yaml:
```yaml
apiVersion: nfs.rook.io/v1alpha1
kind: NFSServer
metadata:
  name: rook-nfs
  namespace: rook-nfs
spec:
  replicas: 1
  exports:
    - name: share1
      server:
        accessMode: ReadWrite
        squash: "none"
      # A Persistent Volume Claim must be created before creating NFS CRD instance.
      persistentVolumeClaim:
        claimName: example-local-claim
        #claimName: nfs-default-claim
  # A key/value list of annotations
  annotations:
    rook: nfs


```
然后通过kubectl create 创建 NFSf 服务器:
```shell
➜  kubectl create -f nfs.yaml
nfsserver.nfs.rook.io/rook-nfs created
```
验证 nfs server 是否运行正常:
```shell
➜  kubectl get pod -n rook-nfs
NAME         READY   STATUS    RESTARTS   AGE
rook-nfs-0   2/2     Running   0          6m9s
```


## Step5: 创建NFS Storage Class
部署OPerator 和 NFSServer实例之后,. 必须创建 StrorageClass 来动态配置 Volume:


```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  labels:
    app: rook-nfs
  name: rook-nfs-share1
parameters:
  exportName: share1
  nfsServerName: rook-nfs
  nfsServerNamespace: rook-nfs
provisioner: nfs.rook.io/rook-nfs-provisioner
reclaimPolicy: Delete
volumeBindingMode: Immediate
```
通过 kubectl create 创建:
```shell
➜  kubectl create -f sc.yaml
storageclass.storage.k8s.io/rook-nfs-share1 created
```
>这里 StorageClass 需要传递以下三个参数:
>1. exportName: 告诉provisioner 使用那个 export;
>2. nfsServerName: NFSServer 实例名字;
>3. nfsServerNamespace：NFSServer实例运行的命名空间;


StorageClass创建之后, 我们接下来就可以创建PVC来引用它:
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: rook-nfs-pv-claim
spec:
  storageClassName: "rook-nfs-share1"
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 1Mi
```
通过kubectl create 进行创建:
```shell
➜  kubectl create -f pvc.yaml
persistentvolumeclaim/rook-nfs-pv-claim created
``` 




## Step6: 创建 Pod 并使用NFS
官方给出的例子 是通过 busybox-rc.yaml 和 web-rc.yaml 创建出两个POD:
1. web server 用来读取和展示 NFS share 的内容;
2. busybox 是往 NFS share写入随机数据,以便 website的内容可以一直更新;
然后通过 web-service.yaml 创建一个service;


最后通过以下命令查看内容:
```shell


$ echo; kubectl exec $(kubectl get pod -l app=nfs-demo,role=busybox -o jsonpath='{.items[0].metadata.name}') -- wget -qO- http://$(kubectl get services nfs-web -o jsonpath='{.spec.clusterIP}'); echo
Mon Sep 13 12:20:59 UTC 2021
nfs-busybox-77c79b4b7b-5fc2w


```






## Step7: 让集群外部服务也可以访问NFS Server
如果外部服务也可以访问NFS Server ,则可以通过修改 rook-nfs 的Service 类型为NodePort 来暴露 NFS 服务:


```shell


➜  kubectl get svc -n rook-nfs
NAME       TYPE       CLUSTER-IP     EXTERNAL-IP   PORT(S)                        AGE
rook-nfs   NodePort   10.1.191.178   <none>        2049:32401/TCP,111:31081/TCP   45m
```
换到其他机器上 通过 mount 进行连接:

```shell

➜  ~ mkdir -p  /mnt/nfs/share
➜  ~ mount -t nfs -o port=32401  10.41.24.236:/ /mnt/nfs/share
➜  ~ cd /mnt/nfs/share
➜  share ls
example-local-claim
➜  share cd example-local-claim
➜  example-local-claim ls
default-rook-nfs-pv-claim-pvc-476a215e-120c-4f76-a73f-3641a5f2af9f
````


