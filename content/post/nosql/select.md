---
title: "主流 nosql 数据库选型"
date: 2021-03-13T20:58:49+08:00
draft: false
tags: [ "mongodb", "hbase" , "redis", "es", "数据库选型", "nosql"]
series: ["nosql"]
categories: ["nosql"]
---
![history of nosql](/history-of-nosql.jpg)
Nosql 目前主流说法已经从 no sql 变为现在的 not only sql,这个不仅仅是因为 nosql 数据库提供了类似 sql 的查询语言,更是因为它为我们解决复杂场景下业务需求和分布式数据处理提供了有效解决方法。  
目前nosql数据库已经有200多个(从 https://hostingdata.co.uk/nosql-database/ 可以看到已经有225个)，但是我们目前常用的数据库有以下四类:
KV数据库、文档数据库、列式数据库、全文搜索引擎。本文就以redis、mongodb、hbase、ES为例说明这几种数据的区别以及各自的适用场景。

# Redis
以redis 为代表的键/值对存储数据库，可以允许你将键/值存储到数据库中，并将可以按照键读取数据。  

*优点:*
1. 轻量且高性能；
2. 支持集群（主从集群，切片集群）；
3. 不仅支持简单的字符串键值对， 它还提供了一系列数据结构类型值，如list、hash、set、sorted set、bitmap、hyperloglog.  

*缺点:*
1. 主要缺点是事务支持不完整：保证了 ACID 中的一致性（C）和隔离性（I），但并不保证原子性（A）和持久性（D）；
2. 集群使用Slot映射表来决定数据分布，规模有一定限制；

*主要场景*
1. 缓存： 其高性能最适合用来做缓存，这也是redis最常用的场景之一;
2. 分布式锁：redis 提供了 Redlock 算法,用来实现基于多个实例的分布式锁;
3. 消息队列：redis 通过list和stream来实现消息队列，数据不大的情况下redis不失为一个好的消息队列方案；
4. 排行榜/计数：redis提供了一些统计模式，常见的有聚合统计、排序统计、二值状态统计和基数统计；


    
# Mongodb
MongoDB 是文档数据库，主要提供数据存储和管理服务。最大的特点就是free-schema,可以将存储任意数据，多种信息存储在一个文档中，而不像关系型数据库那样存储在不同的表中。目前最常用的文档格式是JSON.

*优点*
1. 灵活的查询语言；
2. 易于水平扩展，高可用复制集，可扩展分片集群；
3. 字段增加简单，可以存储复杂的数据格式；

*缺点或者限制*
1. 由于没有像关系型数据库的范式要求，所以数据可能会有冗余存储；
2. 每个文档大小限制为16MB;
3. 事务MVCC的旧数据保存在内存中，所以如果涉及大量文档的数据会带来性能问题，而且mongodb 也提供了默认清理时间transactionLifetimeLimitSeconds，指定多文档事务的生存期。超过此限制的事务将被视为已过期，并且将通过定期清理过程中止；
4. 虽然事务锁定了正在修改的文档，但是其他会话修改该文档并不会被block，而是要求终止该事务然后重试，这会造成浪费因为事务中的其他操作也会重新执行；


*适用场景*
电商、游戏、物流、内容管理、社交、物联网、视频直播等领域都可以使用mongodb;



# hbase
hbase是一种key/value分布式存储系统，仅能按照主键(row key)和主键的range来检索数据，属于列式数据库，是按照列来存储数据的；

*优点*
1. 海量数据存储： 一个表可以有上亿行数据，上百万列；
2. 准实时查询：1s内或者百毫秒内返回查询结果；
3. 横向扩展能力强；

*缺点*  
1. 仅能按照主键(row key)和主键的range来检索数据，这样无法实现复杂的查询；

*适用场景*  
主要解决**海量数据**量场景下I/O较高的问题，可以存储海量数据，因此非常适合数据量极大，但是查询条件比较简单的场景；
比如： 交通GPS、物流（快递员轨迹）、金融（取款信息/消费信息）、电商（浏览日志信息）；

# ES
ES 是分布式的文档存储，定位数据检索服务，是一个搜索服务。其主要通过倒排索引，建立从单词到文档的索引来实现全文搜索的。

*优点*  
1. 支持全文搜索；
2. 自动建立索引，可支持复杂的查询；

*缺点*
1. 其他mapping(同关系数据库的字段)不可修改；
2. 写入性能相对不高，资源损耗较高；

*适用场景*  
ES 主要是用来构建搜索服务：
1. 监控信息、日志数据的检索；
2. 数据查询纬度比较多的场景，如婚恋网站、电商购物；



# 总结
需要缓存服务时一般用redis;  
查询纬度较多时用es;  
数据结构多变且读写性能要求较高用mongodb;  
海量数据且查询比较单一用hbase;  
以上只是一般情况，针对自己的业务场景并根据各个Nosql的特点综合分析来确定用哪个Nosql. 






# 参考  
[A Brief History of NoSQL](http://blog.knuthaugen.no/2010/03/a-brief-history-of-nosql.html)  
[NoSQL (Not Only SQL database)](https://searchdatamanagement.techtarget.com/definition/NoSQL-Not-Only-SQL)  
[Redis设计与实现](https://redisbook.readthedocs.io/en/latest/feature/transaction.html#id12)  
[Limitations in MongoDB Transactions](https://www.dbta.com/Columns/MongoDB-Matters/Limitations-in-MongoDB-Transactions-127057.aspx)