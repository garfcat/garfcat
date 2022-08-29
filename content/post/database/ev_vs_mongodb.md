---
title: "es 与 mongodb比较，es 是否可以作为存储使用呢？" # Title of the blog post.
date: 2022-08-11T14:08:18+08:00 # Date of post creation.
description: "Article description." # Description used for search engine.
featured: true # Sets if post is a featured post, making appear on the home page side bar.
draft: false # Sets whether to render this page. Draft of true will not be rendered.
toc: false # Controls if a table of contents should be generated for first-level links automatically.
# menu: main
featureImage: "/images/qianlingshan.png" # Sets featured image on blog post.
thumbnail: "/images/qianlingshan.png" # Sets thumbnail image appearing inside card on homepage.
shareImage: "/images/path/share.png" # Designate a separate image for social media sharing.
codeMaxLines: 10 # Override global value for how many lines within a code block before auto-collapsing.
codeLineNumbers: true # Override global value for showing of line numbers within code block.
figurePositionShow: true # Override global value for showing the figure label.
categories:
  - Technology
tags:
  - es
  - mongodb
# comment: false # Disable comment if false.
---

两者对比


## 	mongodb	vs es
|  对比   | mongodb  | es |
|  ----  | ----  | ----  | 
| 定位  | 解决关系数据库强 schema 约束的问题 |解决关系数据库的全文搜索性能问题 |
| 主要解决的问题  | 单元格 |单元格 |
| schema  | 无 |无 |
| 事务  | 	4.0之后支持 |不支持 |
| 索引  | B树 |LSM 倒排索引 |
| 时效性  | 高 |有延迟(秒级) |
| 可靠性  | 高 |有丢数据风险 |
| 性能  | 读写均衡 |性能较低 |
| 可扩展性  | 方便 |非常方便 |

mongodb和es 虽然都是文档数据存储,但是两者的定位确是不同:
mongodb 主要定位是文档数据库,提供数据存储, 倾向与OLTP;
es 主要定位是文档搜索引擎,提供搜索服务, 倾向于OLAP;
所以mongodb 主要用于数据的管理, es用于数据的检索服务;

## 那么是否可以用es来作为数据存储服务呢?
es作为存储面临最大的一个问题就是mapping 是不可变的, 如果非要改变可以通过新增字段或者重建索引来实现;
如果是新增加的字段，根据 Dynamic 的设置分为以下三种状况：

当 Dynamic 设置为 true 时，一旦有新增字段的文档写入，Mapping 也同时被更新。
当 Dynamic 设置为 false 时，索引的 Mapping 是不会被更新的，新增字段的数据无法被索引，也就是无法被搜索，但是信息会出现在 _source 中。
当 Dynamic 设置为 strict 时，文档写入会失败。
如果字段已经存在，这种情况下，es 是不允许修改字段的类型的，因为 es 是根据 Lucene 实现的倒排索引，一旦生成后就不允许修改，如果希望改变字段类型，必须使用 Reindex API 重建索引。

不能修改的原因是如果修改了字段的数据类型，会导致已被索引的无法被搜索，但是如果是增加新的字段，就不会有这样的影响;

如果业务更新频率不高且不需要事务可以用es来代替存储;

