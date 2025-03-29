#!/bin/bash

# 配置路径
VENV_DIR="$HOME/venvs/jupyter_env"
PROJECT_DIR="$HOME/workstation/notebooks"

# 检查系统类型并设置包管理器
if [ -f /etc/os-release ]; then
  . /etc/os-release
  case "$ID" in
    ubuntu|debian)
      INSTALLER="sudo apt install -y"
      UPDATE="sudo apt update"
      PY_PKGS="python3 python3-pip python3-venv"
      ;;
    arch|manjaro)
      INSTALLER="sudo pacman -S --noconfirm"
      UPDATE="sudo pacman -Sy"
      PY_PKGS="python python-pip python-virtualenv"
      ;;
    fedora)
      INSTALLER="sudo dnf install -y"
      UPDATE="sudo dnf check-update || true"
      PY_PKGS="python3 python3-pip python3-virtualenv"
      ;;
    centos|rhel)
      INSTALLER="sudo yum install -y"
      UPDATE="sudo yum check-update || true"
      PY_PKGS="python3 python3-pip python3-virtualenv"
      ;;
    opensuse*)
      INSTALLER="sudo zypper install -y"
      UPDATE="sudo zypper refresh"
      PY_PKGS="python3 python3-pip python3-virtualenv"
      ;;
    alpine)
      INSTALLER="sudo apk add"
      UPDATE="sudo apk update"
      PY_PKGS="python3 py3-pip py3-virtualenv"
      ;;
    *)
      echo "❌ 不支持的发行版（$ID），请手动安装 Python3、pip 和 venv"
      exit 1
      ;;
  esac
else
  echo "❌ 无法识别系统类型，缺少 /etc/os-release"
  exit 1
fi

# 更新并安装依赖（仅安装缺失组件）
echo "🔧 检查并安装缺失依赖..."
MISSING_PKGS=()
for pkg in $PY_PKGS; do
  if ! command -v $(echo "$pkg" | cut -d'-' -f1) &>/dev/null; then
    MISSING_PKGS+=("$pkg")
  fi
done

if [ ${#MISSING_PKGS[@]} -gt 0 ]; then
  echo "📦 需要安装: ${MISSING_PKGS[*]}"
  $UPDATE
  $INSTALLER ${MISSING_PKGS[*]}
else
  echo "✅ 所有依赖已安装，跳过安装步骤。"
fi

# 确保系统已安装 nodejs（用于构建 JupyterLab）
if ! command -v node &>/dev/null; then
  echo "🔧 系统未检测到 nodejs，正在安装..."
  if command -v apt &>/dev/null; then
    sudo apt update && sudo apt install -y nodejs npm
  elif command -v dnf &>/dev/null; then
    sudo dnf install -y nodejs
  elif command -v pacman &>/dev/null; then
    sudo pacman -Sy nodejs npm --noconfirm
  else
    echo "❌ 无法自动安装 nodejs，请手动安装后重试"
    exit 1
  fi
fi

# 创建项目目录（如不存在）
if [ ! -d "$PROJECT_DIR" ]; then
  echo "📁 创建项目目录：$PROJECT_DIR"
  mkdir -p "$PROJECT_DIR"
fi

# 创建虚拟环境
if [ ! -d "$VENV_DIR" ]; then
    echo "⚙️ 正在创建虚拟环境..."
    mkdir -p "$VENV_DIR"
    python3 -m venv "$VENV_DIR"
fi

# 激活虚拟环境
source "$VENV_DIR/bin/activate"

# 安装 Jupyter
if ! command -v jupyter &> /dev/null; then
    echo "📦 正在安装 jupyterlab..."
    pip install --upgrade pip
    pip install jupyterlab
fi

echo "📦 已安装 jupyterlab..."

# 在虚拟环境中安装 node/npm
# if ! command -v node &>/dev/null; then
#   echo "🔧 正在为虚拟环境安装 nodejs..."
#   pip install nodejs
# fi

# 智能检测是否需要构建 JupyterLab（如未构建或有插件更新）
if ! jupyter lab build --dev-build=False --minimize=False --check &>/dev/null; then
  echo "🛠️ JupyterLab 正在构建前端资源..."

  # 优先尝试一次轻量构建
  jupyter lab build --dev-build=False --minimize=False || {

    echo '⚠️ 构建失败，尝试最小化配置重试（关闭 dev/minimize）...'

    # fallback：使用 config.py 设置构建配置（永久生效）
    JUPYTER_CONFIG_DIR=$(jupyter --config-dir)
    mkdir -p "$JUPYTER_CONFIG_DIR"
    cat <<EOF > "$JUPYTER_CONFIG_DIR/jupyter_config.py"
# 自动生成：禁用 dev/minimize 构建以避免内存问题
c.LabBuildApp.minimize = False
c.LabBuildApp.dev_build = False
EOF

    echo "✅ 写入 Jupyter 配置成功：" "$JUPYTER_CONFIG_DIR/jupyter_config.py"

    # 再次尝试构建
    jupyter lab build || echo '❌ 二次构建依然失败，请检查内存或手动构建'
  }
fi

# 设置密码（如未设置）
# CONFIG_JSON="$HOME/.jupyter/jupyter_notebook_config.json"
# if [ ! -f "$CONFIG_JSON" ]; then
#     echo "🔐 第一次使用，请设置登录密码："
#     jupyter notebook password
# fi

# 启动 Jupyter
cd "$PROJECT_DIR"
echo "🚀 启动 Jupyter Notebook..."
if command -v jupyter-notebook &>/dev/null; then
  jupyter notebook --ip=0.0.0.0 --port=8888 --no-browser --allow-root --NotebookApp.notebook_dir="$PROJECT_DIR"
else
  jupyter lab --ip=0.0.0.0 --port=8888 --no-browser --allow-root --ServerApp.root_dir="$PROJECT_DIR"
fi