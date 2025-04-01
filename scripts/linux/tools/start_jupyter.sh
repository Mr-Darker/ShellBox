#!/bin/bash

# 添加临时代理
# export https_proxy=http://127.0.0.1:7890
# export http_proxy=http://127.0.0.1:7890

# 颜色输出
green() { echo -e "\\033[32m$1\\033[0m"; }
yellow() { echo -e "\\033[33m$1\\033[0m"; }

# ========== 配置区 ==========
USE_BROWSER=false
ENABLE_TOKEN=true
JUPYTER_IP=0.0.0.0
JUPYTER_PORT=8888
VENV_DIR="$HOME/venvs/jupyter_env"
PROJECT_DIR="$HOME/workstation/notebooks"
# ============================

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

# 判断当前用户是否为 root
IS_ROOT=false
if [ "$(id -u)" -eq 0 ]; then
  IS_ROOT=true
fi

# 检查是否有 sudo 权限（非 root）
if [ "$IS_ROOT" = false ]; then
  if ! sudo -n true 2>/dev/null; then
    echo "⚠️ 当前用户没有 sudo 权限，请手动安装以下软件："
    echo "   $PY_PKGS"
    exit 1
  fi
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

echo "📦 检查 jupyter lab 是否已安装..."
if ! command -v jupyter-lab &> /dev/null; then
  echo "❌ 未找到 jupyter lab，请先安装"
  exit 1
fi

VERSION=$(jupyter lab --version | cut -d. -f1)
echo "🔍 当前 JupyterLab 主版本为：$VERSION.x"

# 设置语言环境变量
echo "🌐 配置环境变量..."
echo "export JUPYTERLAB_LANG=zh-CN"
export JUPYTERLAB_LANG=zh-CN

# 对于 4.x 安装 pip 包
if [[ "$VERSION" -ge 4 ]]; then
  echo "💡 安装适用于 JupyterLab 4.x 的中文语言包..."
  pip show jupyterlab-language-pack-zh-CN &> /dev/null
  if [[ $? -ne 0 ]]; then
    pip install jupyterlab-language-pack-zh-CN
  else
    echo "✅ 已安装 jupyterlab-language-pack-zh-CN，跳过"
  fi

# 对于 3.x 安装 labextension 扩展
elif [[ "$VERSION" -eq 3 ]]; then
  echo "💡 安装适用于 JupyterLab 3.x 的中文扩展..."
  jupyter labextension list | grep '@jupyterlab/translation-zh-CN' &> /dev/null
  if [[ $? -ne 0 ]]; then
    jupyter labextension install @jupyterlab/translation-zh-CN
  else
    echo "✅ 已安装 @jupyterlab/translation-zh-CN，跳过"
  fi

else
  echo "⚠️ 当前版本暂未支持自动识别，手动安装语言包吧"
fi

# pip 插件列表（格式：模块名）
PIP_PACKAGES=(
  # jupyterlab-git
  # jupyterlab-system-monitor
  # python-lsp-server
  # pandas
  # numpy
  # matplotlib
  # seaborn
  # plotly
)

echo "🔧 开始检查并安装 pip 插件..."
for pkg in "${PIP_PACKAGES[@]}"; do
  pip show "$pkg" &> /dev/null
  if [[ $? -eq 0 ]]; then
    green "✅ $pkg 已安装，跳过"
  else
    yellow "📦 安装 $pkg ..."
    pip install "$pkg"
  fi
done

# npm 安装目录本地化（非 root 用户）
# if [ "$IS_ROOT" = false ]; then
#   echo "🔧 设置当前用户 npm 全局安装路径到 ~/.npm-global"
#   mkdir -p "$HOME/.npm-global"
#   npm config set prefix "$HOME/.npm-global"
#   export PATH="$HOME/.npm-global/bin:$PATH"

#   # 永久添加
#   # if ! grep -q 'npm-global' ~/.bashrc; then
#   #   echo 'export PATH=$HOME/.npm-global/bin:$PATH' >> ~/.bashrc
#   # fi
# fi

# npm 插件（多语言补全）
NPM_PACKAGES=(
  # typescript
  # typescript-language-server
  # vscode-langservers-extracted
  # markdown-language-server
  # bash-language-server
)

if [ "$IS_ROOT" = true ]; then
  echo "🧠 开始检查并安装 npm 语言补全支持..."
  for npm_pkg in "${NPM_PACKAGES[@]}"; do
    if npm list -g --depth=0 "$npm_pkg" &> /dev/null; then
      green "✅ $npm_pkg 已全局安装"
    else
      yellow "📦 安装 $npm_pkg ..."
      npm install -g "$npm_pkg"
    fi
  done

  green "✅ 所有插件检查完毕，JupyterLab 插件环境已准备完成！"
fi

# 在虚拟环境中安装 node/npm
# if ! command -v node &>/dev/null; then
#   echo "🔧 正在为虚拟环境安装 nodejs..."
#   pip install nodejs
# fi

# 智能检测是否需要构建 JupyterLab（如未构建或有插件更新）
# if ! jupyter lab build --dev-build=False --minimize=False --check &>/dev/null; then
#   echo "🛠️ JupyterLab 正在构建前端资源..."

#   # 优先尝试一次轻量构建
#   jupyter lab build --dev-build=False --minimize=False || {

#     echo '⚠️ 构建失败，尝试最小化配置重试（关闭 dev/minimize）...'

#     # fallback：使用 config.py 设置构建配置（永久生效）
#     JUPYTER_CONFIG_DIR=$(jupyter --config-dir)
#     mkdir -p "$JUPYTER_CONFIG_DIR"
#     cat <<EOF > "$JUPYTER_CONFIG_DIR/jupyter_config.py"
# # 自动生成：禁用 dev/minimize 构建以避免内存问题
# c.LabBuildApp.minimize = False
# c.LabBuildApp.dev_build = False
# EOF

#     echo "✅ 写入 Jupyter 配置成功：" "$JUPYTER_CONFIG_DIR/jupyter_config.py"

#     # 再次尝试构建
#     jupyter lab build || echo '❌ 二次构建依然失败，请检查内存或手动构建'
#   }
# fi

# 设置密码（如未设置）
# CONFIG_JSON="$HOME/.jupyter/jupyter_notebook_config.json"
# if [ ! -f "$CONFIG_JSON" ]; then
#     echo "🔐 第一次使用，请设置登录密码："
#     jupyter notebook password
# fi

# 获取主版本号
VERSION=$(jupyter lab --version 2>/dev/null | cut -d. -f1)

echo "🔍 检测到 JupyterLab 版本：$VERSION.x"

# 根据版本自动决定使用 Lab 还是 Notebook
if [[ "$VERSION" -ge 4 ]]; then
  MODE="lab"
else
  MODE="notebook"
fi

echo "🌐 请使用浏览器访问：http://localhost:$JUPYTER_PORT 或通过 SSH 隧道访问"
echo "🔑 如果首次运行，请检查终端输出中显示的 token 链接进行访问。"

# 启动 Jupyter
cd "$PROJECT_DIR"
echo "🚀 启动 Jupyter Notebook..."
if [[ "$MODE" == "notebook" ]]; then
  NOTEBOOK_CMD="jupyter notebook --ip=$JUPYTER_IP --port=$JUPYTER_PORT --no-browser"
  [ "$IS_ROOT" = true ] && NOTEBOOK_CMD="$NOTEBOOK_CMD --allow-root"
  $NOTEBOOK_CMD --NotebookApp.notebook_dir="$PROJECT_DIR"
else
  LAB_CMD="jupyter lab --ip=$JUPYTER_IP --port=$JUPYTER_PORT --no-browser"
  [ "$IS_ROOT" = true ] && LAB_CMD="$LAB_CMD --allow-root"
  $LAB_CMD --ServerApp.root_dir="$PROJECT_DIR"
fi