---
title: "mongodb 事务解析" # Title of the blog post. date: 2022-09-02T11:53:16+08:00 # Date of post creation. description: "
description: "Article description." # Description used for search engine.
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
- mongodb
tags:
- transaction

# comment: false # Disable comment if false.
---

## 什么是事务
事务是数据库中的执行单元，包含一个或者多个操作，事务主要有以下几个主要作用:  
    - 所有操作要么一起成功，要么一起失败;  
    - 可以从失败即使是系统故障中正确恢复并保持数据库的一致性;  
    - 提供数据隔离保障可以正确地并发访问数据库；  
事务的属性可以使用ACID来描述:
    A(Atomicity,原子性): 一个事务的所有操作要么成功，要么失败，没有中间状态,如果失败则会回滚到事务开始之前的状态。
    I(Isolation, 隔离性): 当数据库有多个事务并发读写数据时，隔离性可以防止多个事务并发执行时由于交叉执行而导致数据的不一致。事务隔离分为不同级别,分为未提交读（Read uncommitted）、提交读（read committed）、可重复读（repeatable read）和串行化（Serializable）。  
    D(Durability, 持久性): 事务处理结束后，对数据的修改时永久的，即使系统故障也不会丢失;  
    C(Consistency,一致性):  事务执行前后的结果依旧满足正确性的约束，即符合预期。  
AID 都很好理解，但是C是需要多多加理解一下，可以理解AID时手段，C是结果，通过AID可以保证C。举个例子: 变量a=1，事务操作a+1，预期a=2，执行结果a=2，就满足了一致性。期间出现了脏读、不可重复读、幻读，结果就不符合预期了，一致性就没有得到保障。


## 