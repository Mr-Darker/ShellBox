#!/bin/bash

echo "🚀 开始 macOS 开发环境配置脚本"

# ===============================
# 💡 日志记录
# ===============================
LOG_FILE="$HOME/macos_setup_$(date +%Y%m%d_%H%M%S).log"
exec > >(tee -a "$LOG_FILE") 2>&1

# ===============================
# 🧰 Xcode 命令行工具
# ===============================
echo "🧰 检查 Xcode 命令行工具..."
if ! xcode-select -p &>/dev/null; then
    echo "⚠️ 未检测到 Xcode 命令行工具，开始安装..."
    xcode-select --install

    echo ""
    echo "📌 请手动完成安装后重新运行本脚本。"
    echo "🚫 当前脚本将退出，以避免后续步骤失败。"
    exit 0
else
    echo "✅ Xcode 命令行工具已安装，继续执行脚本..."
fi

# ===============================
# 🍺 安装 Homebrew（支持 Intel & Apple Silicon）
# ===============================
echo "🍺 检查并安装 Homebrew..."
if ! command -v brew &>/dev/null; then
    echo "🔧 未检测到 Homebrew，正在安装..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    echo "🔁 添加 Homebrew 到 PATH..."
    ARCH=$(uname -m)
    if [ "$ARCH" = "arm64" ]; then
        echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
        eval "$(/opt/homebrew/bin/brew shellenv)"
    else
        echo 'eval "$(/usr/local/bin/brew shellenv)"' >> ~/.zprofile
        eval "$(/usr/local/bin/brew shellenv)"
    fi
else
    echo "✅ Homebrew 已安装"
fi

# ===============================
# 🔄 更新 Homebrew
# ===============================
echo "🔄 更新 Homebrew..."
brew update
brew upgrade

# ===============================
# 📦 安装常用工具
# ===============================
BREW_PACKAGES=(
    git
    node
    python
    wget
    zsh
    tmux
    neovim
    lazygit
    fzf
    gh
    bat
    htop
)

echo "📦 安装命令行工具..."
for pkg in "${BREW_PACKAGES[@]}"; do
    brew install "$pkg"
done

# ===============================
# 🖥 安装图形界面应用
# ===============================
echo "🖥 安装常用 GUI 应用..."
brew tap homebrew/cask-fonts
CASK_APPS=(
    visual-studio-code
    iterm2
    google-chrome
    font-caskaydia-cove-nerd-font
)

for app in "${CASK_APPS[@]}"; do
    brew install --cask "$app"
done

# ===============================
# 🧠 安装 Rosetta（仅适用于 Apple Silicon）
# ===============================
if [[ $(uname -m) == 'arm64' ]]; then
    echo "🧠 安装 Rosetta..."
    /usr/sbin/softwareupdate --install-rosetta --agree-to-license
fi

# ===============================
# ⚙️ 配置 Zsh + Oh My Zsh + 插件
# ===============================
echo "⚙️ 配置 Zsh 和 Oh My Zsh..."
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    echo "💡 安装 Oh My Zsh..."
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
else
    echo "✅ Oh My Zsh 已安装"
fi

# Powerlevel10k
if [ ! -d "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k" ]; then
    echo "🎨 安装 Powerlevel10k..."
    git clone https://github.com/romkatv/powerlevel10k.git \
        ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k
fi

# 自动补全 & 高亮插件
echo "🔌 安装 Zsh 插件..."
git clone https://github.com/zsh-users/zsh-autosuggestions \
    ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git \
    ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting

# ===============================
# 🔧 设置 .zshrc
# ===============================
echo "🔧 配置 .zshrc 环境变量与别名..."
{
    echo ''
    echo '# >>> 自定义配置 >>>'
    echo 'export PATH="/usr/local/bin:/opt/homebrew/bin:$PATH"'
    echo 'alias ll="ls -la"'
    echo 'alias gs="git status"'
    echo 'alias gp="git pull"'
    echo 'alias gc="git commit"'
    echo 'alias update="brew update && brew upgrade && brew cleanup"'
    echo 'eval "$(fzf --zsh)"'
    echo 'ZSH_THEME="powerlevel10k/powerlevel10k"'
    echo 'plugins=(git zsh-autosuggestions zsh-syntax-highlighting)'
    echo '# <<< 自定义配置 <<<'
} >> ~/.zshrc

# ===============================
# 🔄 应用 shell 设置
# ===============================
echo "🔄 应用 Zsh 配置..."
source ~/.zshrc

# ===============================
# 🔐 Git 配置
# ===============================
echo "🔐 设置 Git 全局配置..."
git config --global init.defaultBranch main
git config --global core.editor "code --wait"

# 如果你愿意可以自动设置用户名和邮箱
# git config --global user.name "Your Name"
# git config --global user.email "your@email.com"

# ===============================
# ⏲ 设置定时任务（示例）
# ===============================
echo "⏲ 设置定时任务（示例脚本，每日凌晨 3 点）..."
CRON_JOB="0 3 * * * /path/to/your/script.sh"
if ! crontab -l | grep -q "/path/to/your/script.sh"; then
    (crontab -l 2>/dev/null; echo "$CRON_JOB") | crontab -
fi

# ===============================
# ✅ 完成提示
# ===============================
echo ""
echo "🎉 macOS 开发环境配置完成！"
echo "📄 安装日志位于：$LOG_FILE"
echo "🔁 请重新打开终端或执行 source ~/.zshrc 以应用所有设置"
