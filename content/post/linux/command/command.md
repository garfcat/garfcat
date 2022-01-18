---
title: "Linux 常用命令" # Title of the blog post.
date: 2022-01-11T10:47:48+08:00 # Date of post creation.
description: "Linux 常用命令" # Description used for search engine.
featured: true # Sets if post is a featured post, making appear on the home page side bar.
draft: false # Sets whether to render this page. Draft of true will not be rendered.
toc: true # Controls if a table of contents should be generated for first-level links automatically.
# menu: main
featureImage: "/images/cat.png" # Sets featured image on blog post.
thumbnail: "/images/cat.png" # Sets thumbnail image appearing inside card on homepage.
shareImage: "/images/path/share.png" # Designate a separate image for social media sharing.
codeMaxLines: 10 # Override global value for how many lines within a code block before auto-collapsing.
codeLineNumbers: true # Override global value for showing of line numbers within code block.
figurePositionShow: true # Override global value for showing the figure label.
categories:
  - linux
tags:
  - command
# comment: false # Disable comment if false.
---

## find
### find 多个条件 AND  
使用多个条件查找，默认是 AND 操作  
```shell
$ find . -name "*.bash" -mtime +180 -size +2K -exec ls -l {} \;
```
在上面的命令中，我们告诉 find 搜索名称中带有字符串 .bash 的文件/目录，它们应该超过 180 天并且大小应该大于 2KB。  
最后，我们使用 -exec 选项对 find 命令产生的结果执行 ls -l 命令。  
### find 多个条件 OR
让我们考虑一个场景，我们需要修改我们之前使用的示例并获取带有字符串 .bash 和 .txt 的文件。要满足此要求，请在 find 命令中使用 -o 选项来指示逻辑 OR 操作。
给出的是完整的命令
```shell
 find . \( -name "*.bash" -o -name "*.txt" \) -mtime +180 -size +2k -exec ls -lh {} \;
```
### find 逻辑 非
查找列出过去 30 天内修改的所有文件并排除 .txt 扩展名的示例, 需要在条件前添加符号 !.  
```shell
$ find . -type f ! -name "*.txt" -mtime -30 -exec ls -l {} \;  
```

## tr 




## 参考  
[find Command Logical AND, OR and NOT Examples](https://arkit.co.in/find-command-logical-and-or-and-not-examples/)   