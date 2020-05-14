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
    
由上可以看出SYN flood 攻击都是收不到ACK导致的。收不到ACK就服务完成连接建立，这些半连接会耗费大量资源，当资源耗尽，就会导致拒绝服务；  


