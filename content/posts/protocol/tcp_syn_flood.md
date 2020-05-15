---
title: "TCP SYN flood 攻击以及解决方法"
date: 2020-05-11T09:25:42+08:00
draft: true
tags: [ "tcp"]
categories: ["协议"]
---
syn flood 攻击是一种拒绝服务攻击，主要有两种方法：   
一种是只发 SYN 不回ACK ； 
一种是在SYN包中欺骗透过欺骗来源IP，让SYN-ACK发送到假的IP地址，从而收不到ACK；
如下图所示：
![tcp_flood](https://raw.githubusercontent.com/garfcat/garfcat/master/static/440px-Tcp_synflood.png)    
由上可以看出SYN flood 攻击都是收不到ACK导致的。收不到ACK就服务完成连接建立，这些半连接会耗费大量资源，当资源耗尽，就会导致拒绝服务；  

一般处理方式调整内核参数， 主要参数如下：  
1. tcp_synack_retries : 如果收不到第三次握手的ack ，需要重试的次数，默认是为5， 设置为0 不进行重试，从而可以加快半连接的回收；  
2. tcp_max_syn_backlog : 半连接的上限；  
3. tcp_syncookies: 默认开启；它的原理是，在TCP服务器接收到TCP SYN包并返回TCP SYN + ACK包时，不分配一个专门的数据区，而是根据这个SYN包计算出一个cookie值。这个
cookie作为将要返回的SYN ACK包的初始序列号。当客户端返回一个ACK包时，根据包头信息计算cookie，与返回的确认序列号(初始序列号 + 1)进行对比，如果相同，则是一个正常连接，然后，分配资源，建立连接。  
                        
                         
