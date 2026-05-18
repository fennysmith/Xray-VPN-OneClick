#!/bin/bash

# Xray 配置显示脚本
# 用法: bash show-config.sh [users|link|all]

CONFIG_FILE="/usr/local/etc/xray/config.json"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 检查是否为 root
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}错误: 请使用 root 权限运行此脚本${NC}"
  echo "使用命令: sudo bash $0"
  exit 1
fi

# 检查配置文件
if [ ! -f "$CONFIG_FILE" ]; then
  echo -e "${RED}错误: 配置文件不存在${NC}"
  exit 1
fi

# 检查 Python3
if ! command -v python3 &> /dev/null; then
  echo -e "${RED}错误: 需要 Python3${NC}"
  exit 1
fi

# 获取服务器 IP（优先 IPv4，回退 IPv6）
SERVER_IP=$(curl -4 -s --connect-timeout 5 ifconfig.me 2>/dev/null | tr -d '[:space:]')
if [[ -z "$SERVER_IP" ]]; then
    SERVER_IP=$(curl -6 -s --connect-timeout 5 ifconfig.me 2>/dev/null | tr -d '[:space:]')
fi
SERVER_IP=${SERVER_IP:-YOUR_SERVER_IP}

# 显示用户列表
show_users() {
  echo -e "${CYAN}================================${NC}"
  echo -e "${CYAN}用户列表${NC}"
  echo -e "${CYAN}================================${NC}"
  echo ""

  python3 << 'EOF'
import json
import sys

try:
    with open('/usr/local/etc/xray/config.json', 'r') as f:
        config = json.load(f)

    users_found = False
    for inbound in config.get('inbounds', []):
        if inbound.get('protocol') == 'vless':
            clients = inbound['settings']['clients']
            if clients:
                users_found = True
                print(f"{'序号':<6} {'邮箱':<30} {'UUID':<38}")
                print("-" * 80)
                for i, client in enumerate(clients, 1):
                    email = client.get('email', 'N/A')
                    uuid = client.get('id', 'N/A')
                    print(f"{i:<6} {email:<30} {uuid:<38}")
                print("")
                print(f"总用户数: {len(clients)}")
            break

    if not users_found:
        print("未找到用户")

except Exception as e:
    print(f"错误: {str(e)}")
    sys.exit(1)
EOF
}

# 显示完整配置
show_all() {
  echo -e "${CYAN}================================${NC}"
  echo -e "${CYAN}Xray 服务器配置${NC}"
  echo -e "${CYAN}================================${NC}"
  echo ""

  python3 << EOF
import json

try:
    with open('$CONFIG_FILE', 'r') as f:
        config = json.load(f)

    # 获取基本信息
    for inbound in config.get('inbounds', []):
        if inbound.get('protocol') == 'vless':
            port = inbound.get('port', 'N/A')
            settings = inbound.get('streamSettings', {}).get('realitySettings', {})

            print("📋 服务器信息:")
            print(f"  地址: $SERVER_IP")
            print(f"  端口: {port}")
            print(f"  协议: VLESS + XTLS-Reality")
            print("")

            print("🔑 Reality 配置:")
            server_names = settings.get('serverNames', [])
            if server_names:
                print(f"  SNI: {server_names[0]}")

            short_ids = settings.get('shortIds', [])
            if short_ids and short_ids[0]:
                print(f"  Short ID: {short_ids[0]}")

            print(f"  伪装目标: {settings.get('dest', 'N/A')}")
            print("")

            print("👥 用户列表:")
            clients = inbound['settings']['clients']
            for i, client in enumerate(clients, 1):
                email = client.get('email', 'N/A')
                uuid = client.get('id', 'N/A')
                flow = client.get('flow', 'N/A')
                print(f"  {i}. {email}")
                print(f"     UUID: {uuid}")
                print(f"     Flow: {flow}")
                print("")

            break

except Exception as e:
    print(f"错误: {str(e)}")
EOF

  # 显示服务状态
  echo -e "${CYAN}📊 服务状态:${NC}"
  if systemctl is-active --quiet xray; then
    echo -e "  ${GREEN}● 运行中${NC}"
  else
    echo -e "  ${RED}● 已停止${NC}"
  fi
  echo ""

  # 显示端口监听
  echo -e "${CYAN}🔌 端口监听:${NC}"
  sudo ss -tlnp | grep xray | awk '{print "  " $4}'
}

# 生成分享链接
generate_link() {
  USER_EMAIL="$1"

  if [ -z "$USER_EMAIL" ]; then
    echo -e "${YELLOW}可用用户:${NC}"
    python3 << 'EOF'
import json
with open('/usr/local/etc/xray/config.json', 'r') as f:
    config = json.load(f)
for inbound in config.get('inbounds', []):
    if inbound.get('protocol') == 'vless':
        for i, client in enumerate(inbound['settings']['clients'], 1):
            print(f"  {i}. {client.get('email', 'N/A')}")
EOF
    echo ""
    read -p "请输入用户邮箱: " USER_EMAIL
  fi

  python3 << EOF
import json
import urllib.parse

try:
    with open('$CONFIG_FILE', 'r') as f:
        config = json.load(f)

    user_uuid = None
    for inbound in config.get('inbounds', []):
        if inbound.get('protocol') == 'vless':
            for client in inbound['settings']['clients']:
                if client.get('email') == '$USER_EMAIL':
                    user_uuid = client.get('id')
                    break

            if user_uuid:
                port = inbound.get('port', 443)
                settings = inbound.get('streamSettings', {}).get('realitySettings', {})

                sni = settings.get('serverNames', ['www.microsoft.com'])[0]
                short_ids = settings.get('shortIds', [''])
                short_id = short_ids[0] if short_ids[0] else ''

                # 注意：这里无法获取 Public Key，需要从原始安装记录中获取
                print("")
                print("⚠️  注意: 需要使用原始安装时的 Public Key")
                print("")
                print("📱 客户端配置参数:")
                print(f"  地址: $SERVER_IP")
                print(f"  端口: {port}")
                print(f"  UUID: {user_uuid}")
                print(f"  SNI: {sni}")
                print(f"  Short ID: {short_id}")
                print(f"  Flow: xtls-rprx-vision")
                print(f"  用户: $USER_EMAIL")
                print("")
                print("💡 提示: 请查看 /root/xray-info.txt 获取 Public Key")
                break
            else:
                print(f"错误: 用户 $USER_EMAIL 不存在")

except Exception as e:
    print(f"错误: {str(e)}")
EOF
}

# 主逻辑
case "${1:-all}" in
  users)
    show_users
    ;;
  link)
    generate_link "$2"
    ;;
  all)
    show_all
    ;;
  *)
    echo "用法: $0 [users|link|all]"
    echo ""
    echo "选项:"
    echo "  users    - 显示所有用户"
    echo "  link     - 生成用户分享链接"
    echo "  all      - 显示完整配置（默认）"
    exit 1
    ;;
esac
