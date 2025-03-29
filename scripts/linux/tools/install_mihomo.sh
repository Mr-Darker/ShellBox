#!/bin/bash

set -e

# ========== 🌐 测试代理连接 ==========
# export https_proxy=http://127.0.0.1:7890
# export http_proxy=http://127.0.0.1:7890

# ========== 🌈 彩色 ==========
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# ========== 🔍 系统架构识别 ==========
detect_arch() {
    ARCH=$(uname -m)
    case "$ARCH" in
        x86_64)   TARGET="linux-amd64" ;;
        aarch64 | arm64) TARGET="linux-arm64" ;;
        armv7l)   TARGET="linux-armv7" ;;
        *) echo -e "${RED}❌ 暂不支持架构：$ARCH${NC}"; exit 1 ;;
    esac
    echo -e "${GREEN}🧠 检测到系统架构：$TARGET${NC}"
}

# ========== 📦 下载并安装 Mihomo ==========
download_and_install_mihomo() {
    if command -v mihomo >/dev/null 2>&1; then
        echo -e "${GREEN}✅ mihomo 已安装，跳过下载和安装。${NC}"
        return
    fi

    echo -e "${GREEN}📡 正在获取最新版本下载链接...${NC}"

    # 获取所有 .gz 下载链接
    ALL_URLS=$(curl -s https://api.github.com/repos/MetaCubeX/mihomo/releases/latest \
        | grep "browser_download_url" \
        | grep "${TARGET}" \
        | grep ".gz" \
        | cut -d '"' -f 4)

    echo -e "${YELLOW}🔍 匹配到的下载链接如下：${NC}"
    echo "$ALL_URLS"

    # 优先匹配策略
    BEST_MATCH=$(echo "$ALL_URLS" | grep -vE 'compatible|go[0-9]+' | grep "${TARGET}" | head -n 1)
    FALLBACK_GO=$(echo "$ALL_URLS" | grep -v "compatible" | grep "go" | grep "${TARGET}" | head -n 1)
    FALLBACK_COMPATIBLE=$(echo "$ALL_URLS" | grep "compatible" | grep "${TARGET}" | head -n 1)

    # 最终选定
    FILENAME=${BEST_MATCH:-${FALLBACK_GO:-$FALLBACK_COMPATIBLE}}

    if [[ -z "$FILENAME" ]]; then
        echo -e "${RED}❌ 无法获取有效下载地址，请检查网络或架构匹配规则。${NC}"
        exit 1
    fi

    FILENAME_BASE=$(basename "$FILENAME")
    echo -e "${GREEN}⬇️ 开始下载 Mihomo: $FILENAME_BASE${NC}"
    wget -O "$FILENAME_BASE" "$FILENAME"

    # 解压逻辑：.gz 是单文件
    if [[ "$FILENAME_BASE" == *.gz ]]; then
        echo -e "${GREEN}📦 解压 gzip 文件...${NC}"
        gunzip -f "$FILENAME_BASE"
        BIN="${FILENAME_BASE%.gz}"
        echo -e "${YELLOW}📁 解压后文件名：$BIN${NC}"
    else
        echo -e "${RED}❌ 不支持的文件格式：$FILENAME_BASE${NC}"
        exit 1
    fi

    # 重命名为标准名，并移动到/usr/local/bin
    mv "$BIN" mihomo
    chmod +x mihomo
    sudo mv mihomo /usr/local/bin/mihomo
    echo -e "${GREEN}✅ 安装完成：/usr/local/bin/mihomo${NC}"
}

# ========== ⚙️ 配置 Mihomo ==========
configure_mihomo() {
    MIHOMO_DIR="$HOME/.config/mihomo"
    CONFIG_URL=""  # 👈 可自定义你的订阅链接
    MMDB_URL="https://github.com/Dreamacro/maxmind-geoip/releases/latest/download/Country.mmdb"

    mkdir -p "$MIHOMO_DIR"

    if [[ -f "$MIHOMO_DIR/config.yaml" ]]; then
        echo -e "${GREEN}✅ config.yaml 已存在，跳过下载${NC}"
    elif [[ -n "$CONFIG_URL" ]]; then
        wget -O "$MIHOMO_DIR/config.yaml" "$CONFIG_URL"
    else
        echo -e "${YELLOW}⚠️ 未提供订阅链接，请将 config.yaml 手动放入：$MIHOMO_DIR${NC}"
    fi

    if [[ -f "$MIHOMO_DIR/Country.mmdb" ]]; then
        echo -e "${GREEN}✅ Country.mmdb 已存在，跳过下载${NC}"
    else
        if ! wget -O "$MIHOMO_DIR/Country.mmdb" "$MMDB_URL"; then
            echo -e "${YELLOW}⚠️ 无法下载 Country.mmdb，请手动放入：$MIHOMO_DIR${NC}"
        fi
    fi
}

# ========== 🔍 获取 mixed-port 端口 ==========
get_mixed_port() {   
    CONFIG_FILE="$HOME/.config/mihomo/config.yaml"
    if [[ -f "$CONFIG_FILE" ]]; then
        PORT=$(grep -E "^mixed-port:" "$CONFIG_FILE" | awk '{print $2}')
        if [[ -n "$PORT" ]]; then
            echo "$PORT"
        else
            # fallback：config.yaml 没写 mixed-port，就默认 7890
            echo "7890"
        fi
    else
        echo "7890"
    fi
}

# ========== 🔁 配置 systemd ==========
setup_systemd_service() {
    SERVICE_FILE="/etc/systemd/system/mihomo.service"

    if [[ -f "$SERVICE_FILE" ]]; then
        echo -e "${GREEN}✅ systemd 服务已存在，跳过写入。${NC}"
    else
        echo -e "${GREEN}⚙️ 创建 Mihomo systemd 服务...${NC}"
        sudo tee "$SERVICE_FILE" > /dev/null <<EOF
[Unit]
Description=Mihomo Proxy Service
After=network.target

[Service]
Type=simple
User=$USER
ExecStart=/usr/local/bin/mihomo -d $HOME/.config/mihomo
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF
    fi

    sudo systemctl daemon-reload
    sudo systemctl enable mihomo
    sudo systemctl restart mihomo
    echo -e "${GREEN}✅ Mihomo 服务已启动${NC}"
}

# ==========🚦等待 Mihomo systemd 启动状态 ==========
wait_for_mihomo_systemd() {
    echo -e "${GREEN}⏳ 等待 mihomo.service 状态为 active...${NC}"
    for i in {1..10}; do
        STATUS=$(systemctl is-active mihomo)
        if [[ "$STATUS" == "active" ]]; then
            echo -e "${GREEN}✅ mihomo.service 已启动。${NC}"
            return 0
        fi
        sleep 1
    done
    echo -e "${RED}❌ 超时：Mihomo 服务未成功启动。${NC}"
    exit 1
}

# ========== 📡 等待端口监听就绪 ==========
wait_for_mihomo() {
    MIXED_PORT=$(get_mixed_port)
    echo -e "${GREEN}⏳ 等待 Mihomo 启动并监听端口 $MIXED_PORT ...${NC}"
    for i in {1..10}; do
        if ss -tuln | grep -q ":$MIXED_PORT"; then
            echo -e "${GREEN}✅ 端口 $MIXED_PORT 已监听，继续执行...${NC}"
            return 0
        fi
        sleep 1
    done
    echo -e "${RED}❌ 超时：Mihomo 未在 $MIXED_PORT 启动成功，请检查服务日志。${NC}"
    exit 1
}

# ========== 🌐 测试代理连接 ==========
test_proxy_connection() {
    export http_proxy="http://127.0.0.1:$MIXED_PORT"
    export https_proxy="http://127.0.0.1:$MIXED_PORT"
    # export all_proxy="socks5://127.0.0.1:$MIXED_PORT"

    echo -e "${GREEN}🌐 测试代理连接（curl https://www.google.com）...${NC}"
    # curl -I https://www.google.com --max-time 5
    if curl -s -I https://www.google.com --max-time 5 | grep -qE "HTTP/(1.1|2) 200"; then    
        echo -e "${GREEN}✅ 代理连接成功${NC}"
    else
        echo -e "${YELLOW}⚠️ 无法访问 Google，可能代理未生效${NC}"
    fi
}

# ========== 🚀 主入口 ==========
main() {
    echo -e "${GREEN}==== Mihomo 自动安装脚本开始 ====${NC}"
    detect_arch
    download_and_install_mihomo
    configure_mihomo
    setup_systemd_service
    wait_for_mihomo_systemd
    wait_for_mihomo
    test_proxy_connection
    echo -e "${GREEN}🎉 所有步骤完成！Mihomo 已安装并运行！${NC}"
}

main