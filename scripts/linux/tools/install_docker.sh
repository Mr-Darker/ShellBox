#!/bin/bash

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_success() { echo -e "${GREEN}$1${NC}"; }
log_warn()    { echo -e "${YELLOW}$1${NC}"; }
log_error()   { echo -e "${RED}$1${NC}"; }

# -----------------------------
# 添加临时代理
# -----------------------------
# export https_proxy=http://127.0.0.1:7890
# export http_proxy=http://127.0.0.1:7890

# -----------------------------
# 通用包管理器检测与安装封装
# -----------------------------
detect_package_manager() {
    if command -v apt-get &> /dev/null; then
        PACKAGE_MANAGER="apt-get"
        UPDATE_CMD="sudo apt-get update"
        INSTALL_CMD="sudo apt-get install -y"
    elif command -v yum &> /dev/null; then
        PACKAGE_MANAGER="yum"
        UPDATE_CMD="sudo yum check-update"
        INSTALL_CMD="sudo yum install -y"
    elif command -v dnf &> /dev/null; then
        PACKAGE_MANAGER="dnf"
        UPDATE_CMD="sudo dnf check-update"
        INSTALL_CMD="sudo dnf install -y"
    else
        log_error "❌ 未检测到受支持的包管理器"
        exit 1
    fi
    log_success "🧭 使用包管理器: $PACKAGE_MANAGER"
}

install_package() {
    local pkg=$1
    if ! command -v "$pkg" &> /dev/null; then
        log_warn "📦 正在安装 $pkg..."
        $INSTALL_CMD "$pkg"
    else
        log_success "✅ $pkg 已安装，跳过"
    fi
}

# -----------------------------
# 系统依赖安装（根据系统类型区分）
# -----------------------------
install_dependencies() {
    detect_package_manager
    $UPDATE_CMD

    source /etc/os-release
    case "$ID" in
        ubuntu|debian)
            local pkgs=(ca-certificates curl gnupg lsb-release software-properties-common apt-transport-https)
            ;;
        centos|rhel|rocky|almalinux)
            local pkgs=(yum-utils device-mapper-persistent-data lvm2 curl)
            ;;
        fedora)
            local pkgs=(dnf-plugins-core curl)
            ;;
        *)
            log_error "❌ 当前系统 $ID 无法识别依赖包列表"
            exit 1
            ;;
    esac

    for pkg in "${pkgs[@]}"; do
        install_package "$pkg"
    done
}

# -----------------------------
# Docker 源添加（官方优先，失败用阿里云）
# -----------------------------
add_docker_repo_official() {
    log_success "🌍 添加官方 Docker 源..."
    source /etc/os-release
    CODENAME=${VERSION_CODENAME:-$(lsb_release -cs)}

    if [[ "$PACKAGE_MANAGER" == "apt-get" ]]; then
        [[ -d /etc/apt/keyrings ]] || sudo install -m 0755 -d /etc/apt/keyrings
        if [[ -f /etc/apt/keyrings/docker.asc && -s /etc/apt/keyrings/docker.asc ]]; then
            log_success "✅ APT GPG 密钥已存在，跳过下载"
        else
            curl -fsSL https://download.docker.com/linux/$ID/gpg -o /etc/apt/keyrings/docker.asc
            sudo chmod a+r /etc/apt/keyrings/docker.asc
        fi
        echo \
          "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/$ID \\
          $CODENAME stable" | \
          sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    elif [[ "$PACKAGE_MANAGER" == "yum" || "$PACKAGE_MANAGER" == "dnf" ]]; then
        sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
    else
        return 1
    fi
}

add_docker_repo_aliyun() {
    log_warn "🚨 官方源失败，尝试使用阿里云源..."
    source /etc/os-release
    CODENAME=${VERSION_CODENAME:-$(lsb_release -cs)}

    if [[ "$PACKAGE_MANAGER" == "apt-get" ]]; then
        curl -fsSL http://mirrors.aliyun.com/docker-ce/linux/$ID/gpg | sudo apt-key add -
        sudo add-apt-repository \
          "deb [arch=amd64] http://mirrors.aliyun.com/docker-ce/linux/$ID \
          $CODENAME stable"
    elif [[ "$PACKAGE_MANAGER" == "yum" || "$PACKAGE_MANAGER" == "dnf" ]]; then
        sudo yum-config-manager --add-repo http://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo
    else
        return 1
    fi
}

# -----------------------------
# Docker 安装与服务启动
# -----------------------------
install_docker_packages() {
    $UPDATE_CMD
    $INSTALL_CMD docker-ce docker-ce-cli containerd.io
}

start_docker() {
    log_success "🚀 启动 Docker 并设置开机自启..."
    sudo systemctl enable docker

    log_success "🌐 配置国内镜像加速器..."

    local config_file="/etc/docker/daemon.json"
    local candidates=(
        "https://f1361db2.m.daocloud.io"
        "https://repo.huaweicloud.com"
        "https://mirrors.tuna.tsinghua.edu.cn"
    )
    local valid_mirrors=()

    log_success "🔎 正在测试可用的镜像加速器..."

    for url in "${candidates[@]}"; do
        local result
        result=$(curl -s -o /dev/null -w "%{http_code} %{time_total}\n" --max-time 2 "$url")
        local code=$(echo "$result" | awk '{print $1}')
        local time=$(echo "$result" | awk '{print $2}')
        if [[ "$code" =~ ^(200|301|302)$ ]]; then
            log_success "✅ 可用: $url (${code}, ${time}s)"
            valid_mirrors+=("\"$url\"")
        else
            log_warn "❌ 不可用: $url (${code}, ${time}s)"
        fi
    done

    if [[ ${#valid_mirrors[@]} -eq 0 ]]; then
        log_warn "⚠️ 没有可用的镜像源，跳过加速器配置"
        return
    fi

    [[ -d /etc/docker ]] || sudo mkdir -p /etc/docker

    if [[ -f "$config_file" && -s "$config_file" ]]; then
        log_warn "⚠️ 检测到已有 Docker 配置文件，是否覆盖？[Y/n]"
        read -r choice
        choice=${choice:-Y}  # 如果为空，默认 Y
        if [[ "$choice" != [Yy] ]]; then
            log_success "✅ 保留现有配置，跳过写入加速器"
            return
        fi
    fi

    # 写入配置文件
    cat <<EOF | sudo tee "$config_file" > /dev/null
{
    "registry-mirrors": [
        $(IFS=,; echo "${valid_mirrors[*]}")
    ]
}
EOF

    # 如果想支持保留其他配置字段，可启用下面 jq 合并逻辑（需安装 jq）
    # if command -v jq &>/dev/null && [[ -f "$config_file" ]]; then
    #     sudo jq '. + {"registry-mirrors": [$(IFS=,; echo "${valid_mirrors[*]}")]}' "$config_file" > /tmp/daemon.new.json
    #     sudo mv /tmp/daemon.new.json "$config_file"
    # fi

    # 重启 Docker 服务
    sudo systemctl daemon-reexec
    sudo systemctl start docker

    # 等待启动成功
    for i in {1..5}; do
        if sudo systemctl is-active docker &>/dev/null; then
            log_success "✅ Docker 启动成功"
            return
        fi
        sleep 1
    done

    log_error "❌ Docker 启动失败，请检查日志"
    exit 1
}

add_user_to_group() {
    if ! groups $USER | grep -qw docker; then
        log_warn "👤 将当前用户加入 docker 用户组（需重新登录）"
        sudo usermod -aG docker $USER
    else
        log_success "✅ 当前用户已在 docker 组中"
    fi
}

# -----------------------------
# 主控制逻辑
# -----------------------------
main() {
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        ID_LIKE=${ID_LIKE:-}
        log_success "🔍 检测到系统：$ID ($ID_LIKE)"
    else
        log_error "❌ 无法识别系统类型，退出"
        exit 1
    fi

    case "$ID" in
        ubuntu|debian|rhel|centos|rocky|almalinux)
            install_dependencies
            ;;
        fedora)
            log_warn "⚠️ Fedora 系统支持实验性安装，继续尝试..."
            install_dependencies
            ;;
        *)
            log_error "❌ 当前系统 $ID 暂不支持自动安装 Docker，请手动安装"
            exit 1
            ;;
    esac

    if add_docker_repo_official; then
        log_success "✅ 官方源添加成功"
    else
        log_warn "❌ 官方源失败，尝试镜像源"
        if add_docker_repo_aliyun; then
            log_success "✅ 阿里云源添加成功"
        else
            log_error "❌ 无法添加任何 Docker 源，请检查网络"
            exit 1
        fi
    fi

    if ! command -v docker &> /dev/null; then
        install_docker_packages
        log_success "✅ Docker 安装成功"
    else
        log_success "✅ Docker 已安装，跳过"
    fi

    start_docker
    add_user_to_group

    log_success "🎉 Docker 安装完成："
    docker --version
    log_warn "⚠️ 请重新登录终端以使 docker 用户组生效"
}

main