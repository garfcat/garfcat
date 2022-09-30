---
title: "mongodb 事务" # Title of the blog post.   
date: 2022-09-02T11:53:16+08:00 # Date of post creation.
description: "Article description." # Description used for search engine.
featured: true # Sets if post is a featured post, making appear on the home page side bar.
draft: false # Sets whether to render this page. Draft of true will not be rendered.
toc: false # Controls if a table of contents should be generated for first-level links automatically.
# menu: main
featureImage: "/images/sky.png" # Sets featured image on blog post.
thumbnail: "/images/sky.png" # Sets thumbnail image appearing inside card on homepage.
shareImage: "/images/path/share.png" # Designate a separate image for social media sharing.
codeMaxLines: 10 # Override global value for how many lines within a code block before auto-collapsing.
codeLineNumbers: false # Override global value for showing of line numbers within code block.
figurePositionShow: true # Override global value for showing the figure label.
categories:
- mongodb
tags:
- transaction

# comment: false # Disable comment if false.
---

## 什么是事务
事务是数据库中的执行单元，包含一个或者多个操作，事务主要有以下几个主要作用:    
- 所有操作要么一起成功，要么一起失败（all-or-nothing）;   
- 可以从失败即使是系统故障中正确恢复并保持数据库的一致性;   
- 提供数据隔离保障可以正确地并发访问数据库；   

事务的属性可以使用ACID来描述:  
- A(Atomicity,原子性): 一个事务的所有操作要么成功，要么失败，没有中间状态,如果失败则会回滚到事务开始之前的状态。  
- I(Isolation, 隔离性): 当数据库有多个事务并发读写数据时，隔离性可以防止多个事务并发执行时由于交叉执行而导致数据的不一致。事务隔离分为不同级别,分为未提交读（Read uncommitted）、提交读（read committed）、可重复读（repeatable read）和串行化（Serializable）。；     
- D(Durability, 持久性): 事务处理结束后，对数据的修改时永久的，即使系统故障也不会丢失;    
- C(Consistency,一致性):  事务执行前后的结果依旧满足正确性的约束，即符合预期;  
AID 都很好理解，但是C是需要多加理解一下，可以理解AID时手段，C是结果，通过AID可以保证C。举个例子: 变量a=1，事务操作a+1，预期a=2，执行结果a=2，就满足了一致性。期间出现了脏读、不可重复读、幻读，结果就不符合预期了，一致性就没有得到保障。


## mongodb 事务
mongodb 的单个文档操作是原子的, 我们可以通过嵌入式文档或者数组在一个文档中组织数据间的关系从而避免多文档多集合的操作。当然在实际开发中单文档操作往往满足不了我们的需求，所以 mongodb 也提供了多文档的事务操作。  
- 从 4.0 版本开始支持复制集的事务  
- 从 4.2 开始开始支持分片集的事务。


## 事务与会话  
- 事务需要关联一个会话，会话本质上是一个上下文，是请求在处理过程中所需的信息: 请求耗时统计、请求占用的锁资源、请求使用的存储快照等信息。  
- 一个会话只能关联一个事务，如果会话结束则事务会终止(abort)。   

## 事务级别(transaction-level)  
### 读事务
读数据主要关心两件事情: 1. 从哪里读数据 2. 读什么样的数据。从哪里读数据由 read preference 指定，读什么样的数据由
read concern 指定。
#### read preference
我们可以在事务开始时设置  read preference(read preference 定义客户端如何从哪里读取数据):  
- 如果事务的 read preference 没有设置，则使用会话设置的 read preference;  
- 如果会话也没有设置 read preference, 则使用客户端设置的 read preference， 默认为 primary;  
可选择的值如下:
- primary: 只从主节点读取数据;  
- primaryPreferred：优先主节点,如果主节点不可用则从成员节点中读取数据;    
- secondary: 只从从节点读取数据;  
- secondaryPreferred: 优先从节点，如果只有一个节点则从主节点读取数据; [更多详情](https://www.mongodb.com/docs/manual/core/read-preference/#mongodb-readmode-secondaryPreferred);  
- nearest: 只考虑节点延迟，不考虑主从;  
所有事务的操作只能在同一个节点进行，而写操作只能在主节点执行，所以事务只能在主节点执行。
#### read concern 
read concern 以事务设置的为准，你可以在事务开始时设置:
- 如果事务没有设置 read concern，则会使用会话设置的 read concern;  
- 如果会话也没有设置，则使用客户端设置的 read concern，其默认值为 "local";  
read concern 可以设置的值如下：  
- local: 返回所有最近可用的数据，不过这些数据有可能会回滚;  
- majority: 返回所有已经被大多数成员确认的数据，也就是数据不能被回滚的;  
- snapshot:  从快照中返回所有被大多数成员确认的数据。


### 写事务  
写事务主要通过  write concern 来配置，同样以事务设置的为准，你可以在事务开始时设置:
- 如果事务没有设置 write concern，则会使用会话设置的 write concern;
- 如果会话也没有设置，则使用客户端设置的 write concern，其默认值为:
  - w: 在MongoDB 5.0 以及之后的版本为 "majority";   
  - w: 在MongoDB 4.4 以及之前的版本为 1;   
w 的值包含如下：  
  - 1: 主节点写入成功则认为成功;  
  - majority: 写操作被复制到大多数节点才算成功;  
## 事务最佳实践  
- 将长事务拆分成小的事务，这样事务不会达到60s超时的限制(超时时间可以调整)，确保操作都使用到了索引，这样可以更快地运行;  
- 每个事务中最多1000个文档修改;  
- 确保配置好 read and write concerns;  
- 合适的错误处理与重试;
- 注意事务会对分片产生性能损耗;  
    
## 总结
使用事务之前，仔细思考是否需要事务，是否可以通过业务上的调整避免使用事务。  

## 参考
[MongoDB 4.0 事务实现解析](https://mongoing.com/%3Fp%3D6084)  
[Transactions](https://www.mongodb.com/docs/manual/core/transactions/#transactions-and-sessions)   
[MongoDB 4 Update: Multi-Document ACID Transactions](https://www.mongodb.com/blog/post/mongodb-multi-document-acid-transactions-general-availability)  





















