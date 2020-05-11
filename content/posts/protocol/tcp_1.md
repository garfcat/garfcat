---
title: "TCP timewait 过多怎么办"
date: 2020-05-07T09:53:51+08:00
tags: [ "tcp"]
categories: ["协议"]
---
要处理timewait 过多的问题，首先应该清楚这个状态是由来，即需要了解TCP 状态迁移的过程； 
<!--more-->
# TCP 三次握手四次挥手状态迁移
```bash
     TCP A                                                TCP B

  1.  CLOSED                                               LISTEN

  2.  SYN-SENT    --> <SEQ=100><CTL=SYN>               --> SYN-RECEIVED

  3.  ESTABLISHED <-- <SEQ=300><ACK=101><CTL=SYN,ACK>  <-- SYN-RECEIVED

  4.  ESTABLISHED --> <SEQ=101><ACK=301><CTL=ACK>       --> ESTABLISHED

  5.  ESTABLISHED --> <SEQ=101><ACK=301><CTL=ACK><DATA> --> ESTABLISHED
```
一般的关闭流程如下所示：
```bash
      TCP A                                                TCP B

  1.  ESTABLISHED                                          ESTABLISHED

  2.  (Close)
      FIN-WAIT-1  --> <SEQ=100><ACK=300><CTL=FIN,ACK>  --> CLOSE-WAIT

  3.  FIN-WAIT-2  <-- <SEQ=300><ACK=101><CTL=ACK>      <-- CLOSE-WAIT

  4.                                                       (Close)
      TIME-WAIT   <-- <SEQ=300><ACK=101><CTL=FIN,ACK>  <-- LAST-ACK

  5.  TIME-WAIT   --> <SEQ=101><ACK=301><CTL=ACK>      --> CLOSED

  6.  (2 MSL)
      CLOSED   
```
两边同时关闭流程如下：
```bash
      TCP A                                                TCP B

  1.  ESTABLISHED                                          ESTABLISHED

  2.  (Close)                                              (Close)
      FIN-WAIT-1  --> <SEQ=100><ACK=300><CTL=FIN,ACK>  ... FIN-WAIT-1
                  <-- <SEQ=300><ACK=100><CTL=FIN,ACK>  <--
                  ... <SEQ=100><ACK=300><CTL=FIN,ACK>  -->

  3.  CLOSING     --> <SEQ=101><ACK=301><CTL=ACK>      ... CLOSING
                  <-- <SEQ=301><ACK=101><CTL=ACK>      <--
                  ... <SEQ=101><ACK=301><CTL=ACK>      -->

  4.  TIME-WAIT                                            TIME-WAIT
      (2 MSL)                                              (2 MSL)
      CLOSED                                               CLOSED
```

TIME-WAIT 是在主动关闭一方(一般是客户端)收到对端FIN包并回复最后一个ACK后进入的状态；随后等待2MSL时间后CLOSED.
MSL 是Maximum Segment Lifetime 报文最长生存时间，2MSL正好是报文一来一回的最大时间；TIME-WAIT的作用主要有两个：a) 确保 ack 可以被对端接收，如未收到可以返回FIN 包；b)确保对端发送的报文被接收或者超时被丢弃，防止未送达的报文对新连接造成影响；

由此可以看出，这个状态是必不可少的，但是并发量比较大的机器上会造成无法新建连接，服务不可用的后果；因此我们要对TIME-WAIT过多的情况做一些调优；  
主要通过设置内核参数来调整：  
1. **tcp_tw_reuse**   
   开启后在协议安全的情况下可以复用TIME-WAIT socket, 这里的协议安全是指两端都开启 timestamps；   
2. tcp_tw_recyle(不建议开启)   
   开启后（也是需要开启timestamp）对TIME-WAIT socket 快速回收, 但是不建议开启，因为开启后可能会导致服务端连接失败；
   具体原因如下   
   >这种机制在 客户端-服务器 一对一的时候，没有任何问题，但是当服务器在负载均衡器后面时，由于负载均衡器不会修改包内部的timestamp值，而互联网上的机器又不可能保持时间的一致性，再加上负载均衡是会重复多次使用同一个tcp端口向内部服务器发起连接的，就会导致什么情况呢：  
   负载均衡通过某个端口向内部的某台服务器发起连接，源地址为负载均衡的内部地址——同一ip
   假如恰巧先后两次连接源端口相同，这台服务器先后收到两个包，第一个包的timestamp被服务器保存着，第二个包又来了，一对比，发现第二个包的timestamp比第一个还老——客户端时间不一致
   服务器基于PAWS，判断第二个包是重复报文，丢弃之   
   
   而且在最新的内核中已经删除了tcp_tw_recycle， 删除记录的commit 如下所示：
  ```bash

    commit 4396e46187ca5070219b81773c4e65088dac50cc
    Author: Soheil Hassas Yeganeh <soheil@google.com>
    Date:   Wed Mar 15 16:30:46 2017 -0400
    
        tcp: remove tcp_tw_recycle
        The tcp_tw_recycle was already broken for connections
        behind NAT, since the per-destination timestamp is not
        monotonically increasing for multiple machines behind
        a single destination address.
```
3. tcp_max_tw_buckets   
   这个参数是控制TIME_WAIT的并发数量。














# 完整状态迁移图如下
以下状态图来自于 [rfc793  TRANSMISSION CONTROL PROTOCOL](http://www.rfc-editor.org/rfc/rfc793.txt)
```bash
                               
                              +---------+ ---------\      active OPEN  
                              |  CLOSED |            \    -----------  
                              +---------+<---------\   \   create TCB  
                                |     ^              \   \  snd SYN    
                   passive OPEN |     |   CLOSE        \   \           
                   ------------ |     | ----------       \   \         
                    create TCB  |     | delete TCB         \   \       
                                V     |                      \   \     
                              +---------+            CLOSE    |    \   
                              |  LISTEN |          ---------- |     |  
                              +---------+          delete TCB |     |  
                   rcv SYN      |     |     SEND              |     |  
                  -----------   |     |    -------            |     V  
 +---------+      snd SYN,ACK  /       \   snd SYN          +---------+
 |         |<-----------------           ------------------>|         |
 |   SYN   |                    rcv SYN                     |   SYN   |
 |   RCVD  |<-----------------------------------------------|   SENT  |
 |         |                    snd ACK                     |         |
 |         |------------------           -------------------|         |
 +---------+   rcv ACK of SYN  \       /  rcv SYN,ACK       +---------+
   |           --------------   |     |   -----------                  
   |                  x         |     |     snd ACK                    
   |                            V     V                                
   |  CLOSE                   +---------+                              
   | -------                  |  ESTAB  |                              
   | snd FIN                  +---------+                              
   |                   CLOSE    |     |    rcv FIN                     
   V                  -------   |     |    -------                     
 +---------+          snd FIN  /       \   snd ACK          +---------+
 |  FIN    |<-----------------           ------------------>|  CLOSE  |
 | WAIT-1  |------------------                              |   WAIT  |
 +---------+          rcv FIN  \                            +---------+
   | rcv ACK of FIN   -------   |                            CLOSE  |  
   | --------------   snd ACK   |                           ------- |  
   V        x                   V                           snd FIN V  
 +---------+                  +---------+                   +---------+
 |FINWAIT-2|                  | CLOSING |                   | LAST-ACK|
 +---------+                  +---------+                   +---------+
   |                rcv ACK of FIN |                 rcv ACK of FIN |  
   |  rcv FIN       -------------- |    Timeout=2MSL -------------- |  
   |  -------              x       V    ------------        x       V  
    \ snd ACK                 +---------+delete TCB         +---------+
     ------------------------>|TIME WAIT|------------------>| CLOSED  |
                              +---------+                   +---------+

```
    
# 参考  

 1. [Coping with the TCP TIME-WAIT state on busy Linux servers
](https://vincent.bernat.ch/en/blog/2014-tcp-time-wait-state-linux)  
 2. [tcp_tw_recycle和NAT造成SYN_ACK问题](https://saview.wordpress.com/2011/09/27/tcp_tw_recycle%E5%92%8Cnat%E9%80%A0%E6%88%90syn_ack%E9%97%AE%E9%A2%98/)