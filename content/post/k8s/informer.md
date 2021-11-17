---
title: "Kubernetes Informer 机制" # Title of the blog post.
date: 2021-11-17T20:43:56+08:00 # Date of post creation.
description: "Kubernetes Informer 机制" # Description used for search engine.
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
  - kubernetes
tags:
  - kubernetes
  - informer
# comment: false # Disable comment if false.
---


## 概述
Kubernetes的其他组件都是通过client-go的Informer机制与Kubernetes API Server进行通信的。
![informer](/static/k8s/informer.png)


在Informer架构设计中,有多个核心组件,分别介绍如下。
1.Reflector Reflector用于监控(Watch)指定的Kubernetes资源,当监控的资源发生变化时,触发相应的变更事件,例如Added(资源添加)事件、Updated(资源更新)事件、Deleted(资源删除)事件,并将其资源对象存放到本地缓存DeltaFIFO中。  
2.DeltaFIFO DeltaFIFO可以分开理解,FIFO是一个先进先出的队列,它拥有队列操作的基本方法,例如Add、Update、Delete、List、Pop、Close等,而Delta是一个资源对象存储,它可以保存资源对象的操作类型,例如Added(添加)操作类型、Updated(更新)操作类型、Deleted(删除)操作类型、Sync(同步)操作类型等。  
3.Indexer Indexer是client-go用来存储资源对象并自带索引功能的本地存储,Reflector从DeltaFIFO中将消费出来的资源对象存储至Indexer。Indexer与Etcd集群中的数据完全保持一致。client-go可以很方便地从本地存储中读取相应的资源对象数据,而无须每次从远程Etcd集群中读取,以减轻Kubernetes API Server和Etcd集群的压力。  


informer 中支持处理资源的三种回掉方法:
- AddFunc :当创建资源对象时触发的事件回调方法。
- UpdateFunc :当更新资源对象时触发的事件回调方法。
- DeleteFunc :当删除资源对象时触发的事件回调方法。

通过Informer机制可以很容易地监控我们所关心的资源事件.

## Reflector
```golang
func NewReflector(lw ListerWatcher, expectedType interface{}, store Store, resyncPeriod time.Duration) *Reflector {
   return NewNamedReflector(naming.GetNameFromCallsite(internalPackages...), lw, expectedType, store, resyncPeriod)
}
```

通过NewReflector实例化Reflector对象,实例化过程中须传入ListerWatcher数据接口对象,它拥有List和Watch方法,用于获取及监控资源列表。只要实现了List和Watch方法的对象都可以称为ListerWatcher。
Reflector对象通过Run函数启动监控并处理监控事件。而在Reflector源码实现中,其中最主要的是ListAndWatch函数,它负责获取资源列表(List)和监控(Watch)指定的Kubernetes API Server资源。
ListAndWatch函数实现可分为两部分:第1部分获取资源列表数据,第2部分监控资源对象。

1.获取资源列表数据ListAndWatch List在程序第一次运行时获取该资源下所有的对象数据并将其存储至DeltaFIFO中。
![listAndWatch](/static/k8s/listAndWatch.png)

a. r.listerWatcher.List用于获取资源下的所有对象的数据,例如,获取所有Pod的资源数据。获取资源数据是由options的ResourceVersion(资源版本号)参数控制的,如果ResourceVersion为0,则表示获取所有Pod的资源数据;如果ResourceVersion非0,则表示根据资源版本号继续获取,功能有些类似于文件传输过程中的“断点续传”,当传输过程中遇到网络故障导致中断,下次再连接时,会根据资源版本号继续传输未完成的部分。可以使本地缓存中的数据与Etcd集群中的数据保持一致。  
b. listMetaInterface.GetResourceVersion用于获取资源版本号,ResourceVersion (资源版本号)非常重要,Kubernetes中所有的资源都拥有该字段,它标识当前资源对象的版本号。每次修改当前资源对象时, Kubernetes API Server都会更改ResourceVersion,使得client-go执行Watch操作时可以根据ResourceVersion来确定当前资源对象是否发生变化。
c. meta.ExtractList用于将资源数据转换成资源对象列表,将runtime.Object对象转换成[]runtime.Object对象。因为r.listerWatcher.List获取的是资源下的所有对象的数据,例如所有的Pod资源数据, 所以它是一个资源列表。
d. r.syncWith用于将资源对象列表中的资源对象和资源版本号存储至DeltaFIFO中,并会替换已存在的对象。
e. r.setLastSyncResourceVersion用于设置最新的资源版本号。

2.监控资源对象

Watch(监控)操作通过HTTP协议与Kubernetes  API  Server建立长连接,接收Kubernetes  API  Server 发来的资源变更事件。Watch操作的实现机制使用HTTP协议的分块传输编码(Chunked Transfer Encoding)。当client-go调用Kubernetes  API  Server时,Kubernetes  API  Server在Response的HTTP Header中设置Transfer-Encoding的值为chunked,表示采用分块传输编码,客户端收到该信息后,便与服务端进行连接,并等待下一个数据块(即资源的事件信息)。

当触发Added(资源添加)事件、Updated  (资源更新)事件、Deleted(资源删除)事件时,将对应的资源对象更新到本地缓存DeltaFIFO中并更新ResourceVersion资源版本号。



## DeltaFIFO


DeltaFIFO 顾名思义 是记录资源对象变化的先进先出队列, 例如资源的 Added(添加)操作类型、Updated(更新)操作类型、Deleted(删除)操作类型、Sync(同步)操作类型等.

```golang
type DeltaFIFO struct {
  
    ......

   items map[string]Deltas 
    
   queue []string  
  ......

}
```
queue字段存储资源对象的key,该key通过KeyOf函数计算得到。items字段通过map数据结构的方式存储,value存储的是对象的Deltas数组。

![deltafifo](/static/k8s/deltafifo.png)
key 是 <namespace>/<name> 组合, 如果namespace 为空,则 key是 <name>.

DeltaFIFO 本质上是一个先进先出的队列, 有生产者和消费者, 其中生产者是 Reflector 调用的Add 方法, 消费者是Controller 调用的Pop 方法.

### 生产者
Reflector在收到资源对象的变更事件时, 会通过 Delta FIFO 的 queueActionLocked 函数 向DeltaFIFO 添加事件. 关键代码如下所示:  
```golang
func (f *DeltaFIFO) queueActionLocked(actionType DeltaType, obj interface{}) error {  
   id, err := f.KeyOf(obj)  
   ....
   oldDeltas := f.items[id]  
   newDeltas := append(oldDeltas, Delta{actionType, obj})  
   newDeltas = dedupDeltas(newDeltas)  

   if len(newDeltas) > 0 {  
      if _, exists := f.items[id]; !exists {  
         f.queue = append(f.queue, id)  
      }
      f.items[id] = newDeltas  
      f.cond.Broadcast()  
   } 
   ...
   return nil  
}  
```
执行流程解释如下 :  
(1)通过 Keyof函数计算出资源对象的key;  
(2)将 actiontype和资源对象构造成 Delta 添加到 oldDeltas 中 生成新的 Delta ,并通过 dedupDeltas 函数进行去重操作;  
(3)将新生成的 Delta 存储到 DeltaFIFO 的 item和 queue 中, 并通过cond. Broadcast通知所有消费者解除阻塞;  



### 消费者
Controller会通过Delta FIFO的POP函数获取数据, 具体逻辑如下:  
```golang
func (f *DeltaFIFO) Pop(process PopProcessFunc) (interface{}, error) {
   f.lock.Lock()
   defer f.lock.Unlock()
   for {
      for len(f.queue) == 0 {
         .....
         f.cond.Wait()
      }
      id := f.queue[0]
      f.queue = f.queue[1:]
      ....
      item, ok := f.items[id]
      .....

      delete(f.items, id)
      err := process(item)
	  if e, ok := err.(ErrRequeue); ok {
   		f.addIfNotPresent(id, item)
   		err = e.Err
	  }

      return item, err
   }
}
```

当队列中没有数据时,通过f.cond.wait阻塞等待数据,只有收到cond. Broadcast时才说明有数据被添加,解除当前阻塞状态。如果队列中不为空,取出f. queue的头部数据将该对象传入 process回调函数,由上层消费者进行处理。如果 processi回调函数处理出错则将该对象重新存入队列。
proccess 的实现是  sharedIndexInformer.HandleDeltas, 具体代码如下:
```golang
func (s *sharedIndexInformer) HandleDeltas(obj interface{}) error {
   s.blockDeltas.Lock()
   defer s.blockDeltas.Unlock()

   // from oldest to newest
   for _, d := range obj.(Deltas) {
      switch d.Type {
      case Sync, Replaced, Added, Updated:
         ....
         if old, exists, err := s.indexer.Get(d.Object); err == nil && exists {
            if err := s.indexer.Update(d.Object); err != nil {
               return err
            }

       		....
            s.processor.distribute(updateNotification{oldObj: old, newObj: d.Object}, isSync)
         } else {
            if err := s.indexer.Add(d.Object); err != nil {
               return err
            }
            s.processor.distribute(addNotification{newObj: d.Object}, false)
         }
      case Deleted:
         if err := s.indexer.Delete(d.Object); err != nil {
            return err
         }
         s.processor.distribute(deleteNotification{oldObj: d.Object}, false)
      }
   }
   return nil
}
```
当资源对象的操作类型为Added、Updated、Deleted时,将该资源对象存储至Indexer(它是并发安全的存储),并通过distribute函数将资源对象分发至SharedInformer。

## Indexer
Indexer是client-go用来存储资源对象并自带索引功能的本地存储,Reflector从DeltaFIFO中将消费出来的资源对象存储至Indexer。Indexer中的数据与Etcd集群中的数据保持完全一致。client-go可以很方便地从本地存储中读取相应的资源对象数据,而无须每次都从远程Etcd集群中读取,这样可以减轻Kubernetes  API  Server和Etcd集群的压力。  
index定义如下:
```golang

type cache struct {
   
   cacheStorage ThreadSafeStore
 
   keyFunc KeyFunc
}

```

index 主要是对  ThreadSafeStore 的封装, 另外增加了 keyFunc 用来生成资源的ID.
ThreadSafeMap是一个内存中的存储,其中的数据并不会写入本地磁盘中,每次的增、删、改、查操作都会加锁,以保证数据的一致性。数据结构定义如下:

```golang
type threadSafeMap struct {
   lock  sync.RWMutex
   items map[string]interface{}

   // indexers maps a name to an IndexFunc
   indexers Indexers
   // indices maps a name to an Index
   indices Indices
}

```
items字段中存储的是资源对象数据,其中items的key通过keyFunc函数计算得到;  
indexers 存储索引函数,

indices 存储缓存器, key 为缓存名称, 和索引名字相同, value为缓存数据;
index 为缓存数据, 结构为key/value

indices 结构如下所示:
![indices](/static/k8s/indices.png)


从index 中获取数据的核心逻辑如下所示:

```golang


func (c *threadSafeMap) ByIndex(indexName, indexedValue string) ([]interface{}, error) {
   c.lock.RLock()
   defer c.lock.RUnlock()

   indexFunc := c.indexers[indexName]
   if indexFunc == nil {
      return nil, fmt.Errorf("Index with name %s does not exist", indexName)
   }

   index := c.indices[indexName]

   set := index[indexedValue]
   list := make([]interface{}, 0, set.Len())
   for key := range set {
      list = append(list, c.items[key])
   }

   return list, nil
}


```
ByIndex接收两个参数:IndexName(索引器名称)和indexKey(需要检索的key)。首先从c.indexers中查找指定的索引器函数,从c.indices中查找指定的缓存器函数,然后根据需要检索的indexKey从缓存数据中查到并返回数据。


## 总结  
通过本文我们了解到了 informer 核心实现逻辑，informer 通过本地缓存大大减轻了对API的压力。


















