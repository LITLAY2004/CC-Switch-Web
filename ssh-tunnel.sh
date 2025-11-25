#!/bin/bash
# CC-Switch SSH 隧道脚本
# 在本地电脑执行此命令

echo "正在建立 SSH 隧道到 CC-Switch Web 服务器..."
echo "服务器: <替换为你的服务器主机/IP>"
echo "本地端口: 3000"
echo "远程端口: 8080"
echo ""
echo "隧道建立后，请在浏览器访问: http://localhost:3000"
echo "按 Ctrl+C 断开隧道"
echo ""

echo "示例命令: ssh -N -L 3000:localhost:8080 user@your-server"
