#!/bin/bash

# 配置路径
VENV_DIR="$HOME/venvs/jupyter_env"
PROJECT_DIR="$HOME/projects/notebooks"

echo "🔍 检查系统依赖..."

# 安装 Python3
if ! command -v python3 &> /dev/null; then
    echo "📆 安装 Python3..."
    sudo apt update && sudo apt install python3 -y
fi

# 安装 venv
if ! python3 -m venv --help &>/dev/null; then
    echo "📆 安装 python3-venv..."
    sudo apt install python3-venv -y
fi

# 安装 pip
if ! command -v pip3 &> /dev/null; then
    echo "📆 安装 pip3..."
    sudo apt install python3-pip -y
fi

# 创建项目目录
mkdir -p "$PROJECT_DIR"

# 创建虚拟环境
if [ ! -d "$VENV_DIR" ]; then
    echo "⚙️ 正在创建虚拟环境..."
    python3 -m venv "$VENV_DIR"
fi

# 激活虚拟环境
source "$VENV_DIR/bin/activate"

# 安装 Jupyter
if ! command -v jupyter &> /dev/null; then
    echo "📆 正在安装 jupyterlab..."
    pip install --upgrade pip
    pip install jupyterlab
fi

# 设置密码（如未设置）
CONFIG_JSON="$HOME/.jupyter/jupyter_notebook_config.json"
if [ ! -f "$CONFIG_JSON" ]; then
    echo "🔐 第一次使用，请设置登录密码："
    jupyter notebook password
fi

# 启动 Jupyter
cd "$PROJECT_DIR"
echo "🚀 启动 Jupyter Notebook..."
jupyter notebook --ip=0.0.0.0 --port=8888 --no-browser