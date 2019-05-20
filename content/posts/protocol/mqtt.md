---
title: "MQTT"
date: 2019-05-15T13:24:24+08:00
draft: false
---


# MQTT 概述
  
MQTT(Message Queuing Telemetry Transport，消息队列遥测传输协议)是最初由IBM开发的一种基于发布/订阅模式的轻量级通信协议,工作在tcp/ip协议簇上。主要优势是
低开销、低带宽，在lot上应用较为广泛。


# MQTT 架构
1. MQTT 是c/s模型，每个客户端通过tcp连接到服务器(broker)；
2. MQTT 是面向消息的。每个消息都是独立的数据块，对于broker来说是不透明的；
3. 每条消息都会发送到一个地址，这个地址称为主题(topic),订阅主题的每个客户端都会收到发布到该主题上的每条消息；

如下所示： 客户端 A、B、C都连接到一个中间broker;    
B、C都订阅topic :dev_info 来获取其他设备的设备信息；  
A发布设备信息到topic dev_info，broker 将该消息转发给所有的订阅者即 BC；  
![mqqtt_arch](https://raw.githubusercontent.com/garfcat/garfcat/master/static/mqtt_arch.png)

# 主题匹配
mqtt 主题是分层级的，通过／划分层级。如 A/B/G ;
注意在订阅时可以使用通配符，发布时不可以使用通配符；  
 通配符 + 匹配任何单个主题，# 匹配任意名称任意数量的主题；   
 例如： A/+/G 可以匹配 A/B/G A/C/G A/D/G 等  
 A/# 可以配置 A/B/C/D/E/F/G 
 
 
# Qos  
 mqtt 支持三种级别的服务质量:  
 "至多一次" "至少一次" "只有一次"：
 
# 最后遗愿
 
# 持久
 
# 安全
 

# 参考  

 1. [维基百科 MQTT](https://zh.wikipedia.org/wiki/MQTT)  
 2. [MQTT manpage](https://mosquitto.org/man/mqtt-7.html)
 3. [MQTT and CoAP, IoT Protocols](https://www.eclipse.org/community/eclipse_newsletter/2014/february/article2.php)