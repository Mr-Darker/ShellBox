#!/bin/bash

# 添加临时代理
# export https_proxy=http://127.0.0.1:7890
# export http_proxy=http://127.0.0.1:7890

# 颜色变量
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # 无颜色

# 检测包管理器
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
        echo -e "${RED}未检测到受支持的包管理器。请手动安装必要的软件包。${NC}"
        exit 1
    fi
}

# 检查并安装软件包
install_package() {
    local pkg=$1
    if ! command -v "$pkg" &> /dev/null; then
        echo -e "${GREEN}正在安装 $pkg...${NC}"
        $INSTALL_CMD "$pkg"
        if [ $? -ne 0 ]; then
            echo -e "${RED}安装 $pkg 失败！${NC}"
            exit 1
        fi
    else
        echo -e "${GREEN}$pkg 已安装，跳过此步骤。${NC}"
    fi
}

# 安装 vim-plug
install_vim_plug() {
    echo -e "${GREEN}安装 vim-plug 插件管理器...${NC}"
    if [ ! -f "$HOME/.vim/autoload/plug.vim" ]; then
        curl -fLo "$HOME/.vim/autoload/plug.vim" --create-dirs \
            https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
        if [ $? -ne 0 ]; then
            echo -e "${RED}vim-plug 下载失败，请检查网络连接。${NC}"
            exit 1
        fi
    else
        echo -e "${GREEN}vim-plug 已安装，跳过此步骤。${NC}"
    fi
}

# 生成 ~/.vimrc
configure_vimrc() {
    echo -e "${GREEN}配置 ~/.vimrc 文件...${NC}"
    cat <<EOF > "$HOME/.vimrc"
" 基础配置
set number
set relativenumber
set cursorline
set mouse=a
set clipboard=unnamedplus

" 代码缩进
set tabstop=4
set shiftwidth=4
set expandtab
set autoindent
set smartindent

" 搜索优化
set ignorecase
set smartcase
set incsearch
set hlsearch

" 启动优化
set lazyredraw
set updatetime=300

" 自动安装 vim-plug（如果未安装）
if empty(glob('~/.vim/autoload/plug.vim'))
  silent !curl -fLo ~/.vim/autoload/plug.vim --create-dirs \
        https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
  autocmd VimEnter * PlugInstall | source $MYVIMRC
endif

" 启用文件类型检测 & 插件支持
filetype plugin indent on

" 插件管理
call plug#begin('~/.vim/plugged')


" 代码补全 & 语法检查
Plug 'neoclide/coc.nvim', {'branch': 'release'}

" 语法解析 & 高亮
Plug 'nvim-treesitter/nvim-treesitter', {'do': ':TSUpdate'}

" 代码片段
Plug 'SirVer/ultisnips'
Plug 'honza/vim-snippets'

" 代码格式化（Python & JS）
Plug 'psf/black', { 'for': 'python' }
Plug 'prettier/vim-prettier', { 'do': 'npm install' }

" 目录树
Plug 'preservim/nerdtree'

" 状态栏美化
Plug 'vim-airline/vim-airline'

call plug#end()

" 绑定快捷键
nnoremap <leader>n :NERDTreeToggle<CR>  " <leader>n 打开/关闭目录树
nnoremap <leader>f :Files<CR>  " <leader>f 搜索文件（需要 fzf）

" 代码补全（Coc.nvim）
inoremap <silent><expr> <TAB> pumvisible() ? "\<C-n>" : "\<TAB>"
nnoremap <silent> gd <Plug>(coc-definition)  " 跳转到定义
nnoremap <silent> K :call CocActionAsync('doHover')<CR>  " 显示文档
nnoremap <leader>f :CocFix<CR>  " 自动修复代码

" 代码格式化
nnoremap <leader>b :Black<CR>  " Python 代码格式化
nnoremap <leader>p :Prettier<CR>  " JS/TS/HTML 代码格式化
EOF
}

# 安装插件（静默无交互）
install_plugins() {
    cd "$HOME" || exit 1
    echo -e "${GREEN}安装 Vim 插件（静默模式）...${NC}"
    vim -E -s -u "$HOME/.vimrc" +PlugInstall +qall
}

# 修复 vim-prettier 问题
fix_vim_prettier_issue() {
    local prettier_dir="$HOME/.vim/plugged/vim-prettier"
    if [ -d "$prettier_dir" ]; then
        echo -e "${GREEN}检测到 vim-prettier，尝试修复依赖问题...${NC}"
        cd "$prettier_dir"
        if ! npm install --legacy-peer-deps; then
            echo -e "${YELLOW}--legacy-peer-deps 安装失败，尝试 --force...${NC}"
            npm install --force
        fi
        npm audit fix --force > /dev/null 2>&1
        echo -e "${GREEN}执行 PlugClean 和 PlugUpdate 清理插件...${NC}"
        cd "$HOME" || exit 1
        vim -E -s -u "$HOME/.vimrc" +PlugClean! +qall
        vim -E -s -u "$HOME/.vimrc" +PlugUpdate +qall
    else
        echo -e "${GREEN}未找到 vim-prettier，跳过修复步骤。${NC}"
    fi
}

# 安装 coc.nvim 插件（静默）
install_coc_extensions() {
    cd "$HOME" || exit 1
    echo -e "${GREEN}安装 Coc.nvim 扩展（静默模式）...${NC}"
    vim -E -s -u "$HOME/.vimrc" +"CocInstall -sync coc-python coc-clangd coc-tsserver" +qall
}

# 主函数
main() {
    detect_package_manager
    $UPDATE_CMD
    install_package vim
    install_package curl
    install_package git
    install_package nodejs
    install_package npm
    install_package python3
    install_package python3-pip
    install_package dos2unix
    install_package fzf
    install_vim_plug
    configure_vimrc
    install_plugins
    fix_vim_prettier_issue
    install_coc_extensions
    echo -e "${GREEN}Vim 配置完成！${NC}"
}

# 执行主函数
main