#!/bin/bash

# 推荐放置脚本路径：~/scripts 或 ~/
# 不建议从临时目录执行，否则配置 source 会失败

echo "🚀 开始 macOS 开发环境配置脚本"

# 获取当前使用的 Shell
CURRENT_SHELL=$(basename "$SHELL")
if [ "$CURRENT_SHELL" != "zsh" ]; then
    echo "⚠️ 当前使用的 shell 是 $CURRENT_SHELL，建议切换为 zsh 后执行本脚本"
fi

# 获取当前 CPU 架构
ARCH=$(uname -m)

# 设置当前配置文件
if [ "$ARCH" = "arm64" ]; then
    PROFILE_FILE="$HOME/.zprofile"
else
    PROFILE_FILE="$HOME/.bash_profile"
fi

# 设置 ZSH_CUSTOM 路径
ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

# ===============================
# 💡 日志记录
# ===============================
LOG_FILE="$HOME/macos_setup_$(date +%Y%m%d_%H%M%S).log"
exec > >(tee -a "$LOG_FILE") 2>&1

# ===============================
# 🔨 封装自定义函数
# ===============================
set_or_replace_zshrc_line() {       # 封装替换文件行或追加的函数，默认是 .zshrc 文件
    local key="$1"                  # 匹配前缀，如 ZSH_THEME=
    local value="$2"                # 要设置的新行，比如 ZSH_THEME="powerlevel10k/powerlevel10k"
    local file="${3:-$HOME/.zshrc}" # 可选参数，默认是 ~/.zshrc

    if grep -q "^$key" "$file"; then
        echo "🔁 更新 $key..."
        sed -i '' "s|^$key.*|$value|" "$file"
    else
        if ! grep -Fxq "$value" "$file"; then
            echo "➕ 添加 $key..."
            echo "$value" >> "$file"
        fi
    fi
}

install_brew_package() {            # 安装 Homebrew 命令行工具（brew install）
    local cmd="$1"                  # 既是 brew 包名，也是命令名（一般情况）
    local brew_name="${2:-$cmd}"    # 如果 brew 包名与命令名不一致，可传第二个参数

    if command -v "$cmd" &>/dev/null; then
        echo "✅ $cmd 已存在于系统中，跳过安装"
    elif brew list "$brew_name" &>/dev/null; then
        echo "✅ $brew_name 已通过 Homebrew 安装，跳过"
    else
        echo "📥 安装 $brew_name..."
        brew install "$brew_name"
    fi
}

install_cask_app() {                # 安装 GUI 应用程序（brew install --cask）
    local brew_name="$1"            # Homebrew 的包名，比如 iterm2
    local app_name="$2"             # App 的名字，比如 iTerm.app

    # 当关键词为空（如字体类），只用 brew list 判断
    if [ -z "$app_name" ]; then
        if brew list --cask "$brew_name" &>/dev/null; then
            echo "✅ $brew_name 已通过 Homebrew 安装，跳过"
        else
            echo "📥 安装 $brew_name..."
            brew install --cask "$brew_name"
        fi
        return
    fi

    # 不区分大小写地搜索 /Applications 中的 .app 文件夹名
    if find /Applications -maxdepth 1 -iname "*${app_name}*.app" | grep -q .; then
        echo "✅ 检测到与 [$app_name] 匹配的 App 已安装，跳过安装"
    elif brew list --cask "$brew_name" &>/dev/null; then
        echo "✅ $brew_name 已通过 Homebrew 安装，跳过"
    else
        echo "📥 安装 $brew_name..."
        brew install --cask "$brew_name"
    fi
}

clone_if_not_exists() {             # 从远程 Git 仓库克隆代码到本地指定目录
    local repo_url="$1"             # 仓库地址
    local target_dir="$2"           # 克隆目标目录

    if [ -d "$target_dir" ]; then
        echo "✅ [$target_dir] 已存在，跳过 clone"
    else
        echo "📥 Clone 仓库: $repo_url → $target_dir"
        git clone "$repo_url" "$target_dir"
    fi
}

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
    {
        echo ''
        echo '# >>> 配置 Homebrew 环境变量 >>>'
        echo 'eval "$(/opt/homebrew/bin/brew shellenv)"'
        echo '# <<< 配置 Homebrew 环境变量 <<<'
    } >> "$PROFILE_FILE"
    echo "🔁 请重新打开终端或执行 source "$PROFILE_FILE" 以应用所有设置"
else
    echo "✅ Homebrew 已安装"
fi

# ===============================
# 🔄 更新 Homebrew
# ===============================
echo "🔄 更新 Homebrew..."
if ! brew update; then
    echo "❌ Homebrew 更新失败，请检查网络或代理设置"
    exit 0
fi
brew upgrade

# ===============================
# 📦 安装常用命令行工具（避免重复安装）
# ===============================
echo "📦 安装命令行工具..."

# 键是命令名，值是 Homebrew 包名
declare -A BREW_CMD_MAP=(
    [node]="node"
    [wget]="wget"
    [htop]="htop"
    [java]="openjdk"
    [qt]="qmake"
)

for cmd in "${!BREW_CMD_MAP[@]}"; do
    install_brew_package "$cmd" "${BREW_CMD_MAP[$cmd]}"
done

# ===============================
# 🖥 安装常用 GUI 应用（避免重复安装）
# ===============================
echo "🖥 安装常用 GUI 应用..."

declare -A CASK_APPS=(
    [iterm2]="iTerm"
    [qt-creator]="qt"
    [font-caskaydia-cove-nerd-font]=""   # 字体不检查
)

brew tap homebrew/cask-fonts
for brew_name in "${!CASK_APPS[@]}"; do
    app_name="${CASK_APPS[$brew_name]}"
    install_cask_app "$brew_name" "$app_name"
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
    # echo "💡 安装 Oh My Zsh..."
    # sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

    echo "⚠️ 未检测到 Oh My Zsh，建议先手动安装："
    echo ""
    echo "  👉 sh -c \"\$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)\""
    echo ""
    echo "📌 请安装后重新运行本脚本"
    exit 0
else
    echo "✅ Oh My Zsh 已安装"
fi

# Powerlevel10k
if [ ! -d "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k" ]; then
    echo "🎨 安装 Powerlevel10k..."
    clone_if_not_exists https://github.com/romkatv/powerlevel10k.git \
        "$ZSH_CUSTOM/themes/powerlevel10k"
fi

# 自动补全 & 高亮插件
echo "🔌 安装 Zsh 插件..."
clone_if_not_exists https://github.com/zsh-users/zsh-autosuggestions \
    "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
clone_if_not_exists https://github.com/zsh-users/zsh-syntax-highlighting \
    "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"
clone_if_not_exists https://github.com/zsh-users/zsh-completions \
    "$ZSH_CUSTOM/plugins/zsh-completions"

# ===============================
# 🔧 设置 .zshrc
# ===============================
touch "$HOME/.zshrc"
ZSHRC="$HOME/.zshrc"

# 主题设置
set_or_replace_zshrc_line 'ZSH_THEME=' 'ZSH_THEME="powerlevel10k/powerlevel10k"' "$ZSHRC"

# 插件设置
set_or_replace_zshrc_line 'plugins=' 'plugins=(git zsh-autosuggestions zsh-syntax-highlighting zsh-completions)' "$ZSHRC"

# 自动更新配置
set_or_replace_zshrc_line "zstyle ':omz:update' mode" "zstyle ':omz:update' mode auto" "$ZSHRC"
set_or_replace_zshrc_line "zstyle ':omz:update' frequency" "zstyle ':omz:update' frequency 3" "$ZSHRC"

# 追加自定义别名
if ! grep -q '# >>> 自定义别名 >>>' "$ZSHRC"; then
    echo "🔧 配置 .zshrc 别名..."
    {
        echo ''
        echo '# >>> 自定义别名 >>>'
        echo 'alias ll="ls -la"'
        echo 'alias gs="git status"'
        echo 'alias gp="git pull"'
        echo 'alias gc="git commit"'
        echo 'alias update="brew update && brew upgrade && brew cleanup"'
        echo '# <<< 自定义别名 <<<'
    } >> "$ZSHRC"
else
    echo "✅ 已添加别名块，跳过"
fi

# ===============================
# 📦 配置 OpenJDK
# ===============================
echo "📦 检查 OpenJDK 是否已安装..."
if ! command -v java &>/dev/null; then
    if [ -d "/opt/homebrew/opt/openjdk" ]; then
        echo "📍 检测到 OpenJDK 安装目录，但未配置 JAVA_HOME"
        
        if ! grep -q 'JAVA_HOME' ~/.zshrc; then
            echo "➕ 配置 JAVA_HOME 到 ~/.zshrc..."
            {
                echo ''
                echo '# >>> Java Development Kit >>>'
                echo 'export JAVA_HOME="/opt/homebrew/opt/openjdk"'
                echo 'export PATH="$JAVA_HOME/bin:$PATH"'
                echo '# <<< Java Development Kit <<<'
            } >> ~/.zshrc

            echo "📌 请重新打开终端或执行：source \"$ZSHRC\" 以应用 JDK 配置"
        else
            echo "✅ JDK 环境变量已在 ~/.zshrc 中配置，跳过"
        fi
    else
        echo "❌ 未检测到 JDK，请先执行：brew install openjdk"
    fi
else
    echo "✅ Java 已安装并可用，跳过配置"
fi

# ===============================
# 📦 安装 Qt（如果未安装）
# ===============================
echo "📦 检查 Qt 是否已安装..."

if ! command -v qmake &>/dev/null; then
    # 检查 Qt 安装路径（通过 brew 安装的路径）
    if brew --prefix qt &>/dev/null; then
        QT_PREFIX=$(brew --prefix qt 2>/dev/null)
        if [ -z "$QT_PREFIX" ]; then
            echo "❌ 无法获取 Qt 安装路径，请检查 brew 环境或重新执行 source $PROFILE_FILE"
            exit 0
        fi

        if ! grep -q 'QTDIR' ~/.zshrc; then
            echo "➕ 配置 Qt 环境变量到 ~/.zshrc..."
            {
                echo ''
                echo '# >>> Qt 环境变量配置 >>>'
                echo "export QTDIR=\"$QT_PREFIX\""
                echo 'export PATH="$QTDIR/bin:$PATH"'
                echo '# <<< Qt 环境变量配置 <<<'
            } >> ~/.zshrc

           echo "📌 请重新打开终端或执行：source \"$ZSHRC\" 以应用 Qt 配置"
        else
            echo "✅ Qt 环境变量已在 ~/.zshrc 中配置，跳过"
        fi
    else
        echo "❌ 未检测到 Qt，请先执行：brew install qt"
    fi
else
    echo "✅ Qt 已安装并可用，跳过配置"
fi

# ===============================
# 🔐 Git 配置
# ===============================
# echo "🔐 设置 Git 全局配置..."
# git config --global init.defaultBranch main
# git config --global core.editor "code --wait"

# 如果你愿意可以自动设置用户名和邮箱
# git config --global user.name "Your Name"
# git config --global user.email "your@email.com"

# ===============================
# ⏲ 设置定时任务（示例）
# ===============================
# echo "⏲ 设置定时任务（示例脚本，每日凌晨 3 点）..."
# CRON_JOB="0 3 * * * /path/to/your/script.sh"
# if ! crontab -l | grep -q "/path/to/your/script.sh"; then
#     (crontab -l 2>/dev/null; echo "$CRON_JOB") | crontab -
# fi

# ===============================
# ✅ 完成提示
# ===============================
brew doctor || echo "⚠️ 建议执行 brew doctor 检查环境问题"
echo ""
echo "🎉 macOS 开发环境配置完成！"
echo "📄 安装日志位于：$LOG_FILE"
echo "🔁 请重新打开终端或执行 source ~/.zshrc 以应用所有设置"
