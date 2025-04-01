# 提示调整执行策略
if ((Get-ExecutionPolicy) -eq "Restricted") {
	# RemoteSigned 意味着本地脚本无需签名，远程下载的脚本需签名，推荐用于个人环境
    Write-Warning "⚠️ 当前脚本执行策略为 Restricted，可能会阻止脚本运行。"
    Write-Host "建议执行以下命令解除限制：" -ForegroundColor Yellow
    Write-Host "Set-ExecutionPolicy -Scope CurrentUser RemoteSigned" -ForegroundColor Cyan
}

Write-Host "`n===== 开始备份并更新 PowerShell 配置 =====" -ForegroundColor Cyan
# 当前时间戳（一次性定义，确保一致）
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"

# 备份并重置 $PROFILE 文件
if (Test-Path $PROFILE) {
    $profileBackup = "$PROFILE.bak.$timestamp"
    Move-Item -Path $PROFILE -Destination $profileBackup -Force
    Write-Host "📝 $PROFILE 已备份到: $profileBackup"
}
New-Item -ItemType File -Path $PROFILE -Force | Out-Null
Write-Host "✅ 已创建新的 PowerShell 配置文件: $PROFILE"

# 配置模块的文件路径
$PSConfigPath = "$HOME\.powershell"

# 备份旧的 PowerShell 模块配置目录
if (Test-Path $PSConfigPath) {
    $folderBackup = "${PSConfigPath}_backup_$timestamp"
    Move-Item -Path $PSConfigPath -Destination $folderBackup -Force
    Write-Host "📂 旧的配置文件夹已备份到: $folderBackup"
}

# 创建 PowerShell 配置目录（如果不存在则创建）
if (!(Test-Path $PSConfigPath)) {
    New-Item -ItemType Directory -Path $PSConfigPath -Force | Out-Null
    Write-Host "✅ 已创建 PowerShell 配置目录: $PSConfigPath"
} else {
    Write-Host "📂 PowerShell 配置目录已存在，跳过创建"
}

# 设置 PowerShell 的输出编码为 UTF-8
# [Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# 设定 PowerShell UTF-8 编码
# $PSDefaultParameterValues['Out-File:Encoding'] = 'utf8'
# $PSDefaultParameterValues['Get-Content:Encoding'] = 'utf8'
# $PSDefaultParameterValues['Set-Content:Encoding'] = 'utf8'

Write-Host "`n===== 开始写入 PowerShell 配置文件 =====" -ForegroundColor Cyan
# 写入 $PROFILE，确保终端启动时自动加载配置
$ProfileConfig = @'
# 设置 PowerShell 的输出编码为 UTF-8
# [Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# 设置 Windows 控制台的默认代码页为 UTF-8
# chcp 65001 | Out-Null

# 以 UTF-8 读取并加载所有文件
# $PSDefaultParameterValues['Out-File:Encoding'] = 'utf8'
# $PSDefaultParameterValues['Get-Content:Encoding'] = 'utf8'
# $PSDefaultParameterValues['Set-Content:Encoding'] = 'utf8'

# 检查是否以管理员身份运行
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if ($isAdmin) {
    Write-Warning "`n⚠️ 检测到当前 PowerShell 是以管理员身份运行。Scoop 应在普通用户终端中安装和使用。"
    Write-Warning "请关闭此窗口，用普通权限重新打开 PowerShell。`n"
}

Write-Host "`n===== 检查并自动安装 Winget 软件 =====" -ForegroundColor Green
$wingetPackages = @(
    @{ Name = "Oh My Posh"; Package = "JanDeDobbeleer.OhMyPosh"; Command = "oh-my-posh" },
    @{ Name = "gsudo"; Package = "gerardog.gsudo"; Command = "gsudo" },
    @{ Name = "zoxide"; Package = "ajeetdsouza.zoxide"; Command = "zoxide" },
    @{ Name = "bat"; Package = "sharkdp.bat"; Command = "bat" },
    @{ Name = "fzf"; Package = "junegunn.fzf"; Command = "fzf" },
    @{ Name = "fd"; Package = "sharkdp.fd"; Command = "fd" }
)

foreach ($software in $wingetPackages) {
    $cmd = $software.Command
    $pkg = $software.Package
    $name = $software.Name

    if (!(Get-Command $cmd -ErrorAction SilentlyContinue)) {
        Write-Host "📦 安装 $pkg ..."
        winget install --id=$pkg --silent --accept-source-agreements --accept-package-agreements
    } else {
        Write-Host "✅ $name 已安装，跳过" -ForegroundColor DarkGray
    }
}

Write-Host "`n===== 检查并安装 Nerd Font 字体 =====" -ForegroundColor Green
# 尝试从注册表读取系统字体列表（两个位置：所有用户 + 当前用户）
$fontsHKLM = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts").PSObject.Properties
$fontsHKCU = (Get-ItemProperty "HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts").PSObject.Properties

# 定义多个关键词
$fontKeywords = @(
    "Caskaydia",
    "Meslo",
    "Nerd"
)

# 匹配任何一个关键词即可视为已安装
$matchedFonts = @()
foreach ($kw in $fontKeywords) {
    $matchHKLM = $fontsHKLM | Where-Object { $_.Name -like "*$kw*" }
    $matchHKCU = $fontsHKCU | Where-Object { $_.Name -like "*$kw*" }

    foreach ($f in $matchHKLM) {
        $matchedFonts += [PSCustomObject]@{ Name = $f.Name; Source = "System (HKLM)" }
    }
    foreach ($f in $matchHKCU) {
        $matchedFonts += [PSCustomObject]@{ Name = $f.Name; Source = "User (HKCU)" }
    }
}

if ($matchedFonts.Count -eq 0) {
    # 未匹配任何字体
    Write-Warning "⚠️ 未检测到以下任何字体："
    $fontKeywords | ForEach-Object { Write-Host "   - $_" }

    # 下载 URL（可自定义或更新）
    $fontZipUrl = "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/CascadiaCode.zip"
    $zipPath = "$env:TEMP\CascadiaCode.zip"
    $fontDir = "$env:TEMP\CascadiaCode"
    $fontFile = Join-Path $fontDir "CaskaydiaCoveNerdFont-Regular.ttf"

    try {
        # 下载 zip 文件
        if (!(Test-Path $zipPath)) {
            if ($PSVersionTable.PSVersion.Major -lt 6) {
                Invoke-WebRequest -Uri $fontZipUrl -OutFile $zipPath -UseBasicParsing
            } else {
                Invoke-WebRequest -Uri $fontZipUrl -OutFile $zipPath
            }
            Write-Host "📥 字体压缩包下载成功：$zipPath"
        }  else {
            Write-Host "📦 已存在字体压缩包，跳过下载：$zipPath" -ForegroundColor DarkGray
        }

        # 解压字体文件
        if (!(Test-Path $fontDir)) {
            Expand-Archive -Path $zipPath -DestinationPath $fontDir -Force
            Write-Host "📂 已解压字体文件到：$fontDir"
        }  else {
            Write-Host "📂 已存在解压目录，跳过解压：$fontDir" -ForegroundColor DarkGray
        }

        # 检查并安装字体
        if (Test-Path $fontFile) {
            Write-Host "📌 正在安装字体：$(Split-Path $fontFile -Leaf)"
            # Start-Process $fontFile -Verb RunAs
            if ($isAdmin) {
                # 推荐替代方式：强制复制到字体目录（无需手动点安装）
                # 0x14 是一个特殊的数字 ID，表示字体文件夹，也就是 C:\Windows\Fonts
                $shellApp = New-Object -ComObject Shell.Application
                $fontsFolder = $shellApp.Namespace(0x14)
                $fontsFolder.CopyHere($fontFile)
                Write-Host "✅ 已静默安装字体到系统字体目录" -ForegroundColor Green
            } else {
                # 普通用户 → 打开字体窗口让用户手动点击安装
                Start-Process $fontFile
                Write-Warning "⚠️ 当前为普通用户，将打开字体预览窗口，请手动点击【安装】按钮。"    
            }
        } else {
            Write-Warning "❌ 找不到字体文件：$fontFile"
            Write-Warning "⚠️ 安装字体失败，请手动前往 NerdFonts 官网下载安装 CaskaydiaCove Nerd Font 字体："
   		    Write-Warning "👉 https://www.nerdfonts.com/font-downloads"
        }

        # 清理下载和解压内容
        $confirm = Read-Host "🧹 是否现在清理下载的字体文件？输入 Y 确认，其他跳过"
        if ($confirm -match '^[Yy]$') {
            Remove-Item $zipPath -Force -ErrorAction SilentlyContinue
            Remove-Item $fontDir -Recurse -Force -ErrorAction SilentlyContinue
            Write-Host "✅ 已清理临时文件" -ForegroundColor DarkGray
        } else {
            Write-Host "📂 临时文件保留在：" -ForegroundColor Cyan
            Write-Host "  - $zipPath" -ForegroundColor DarkGray
            Write-Host "  - $fontDir" -ForegroundColor DarkGray
        }
	} catch {
    	Write-Warning "⚠️ 安装字体失败，请手动前往 NerdFonts 官网下载安装 CaskaydiaCove Nerd Font 字体："
   		Write-Warning "👉 https://www.nerdfonts.com/font-downloads"
   	}

    Write-Warning "请手动打开 Windows Terminal 设置，将 PowerShell 的字体设置为：`"CaskaydiaCove Nerd Font`""
    Write-Warning "路径：设置 → 外观 → 字体 → 选择 `"CaskaydiaCove Nerd Font`""
} else {
    Write-Host "✅ 已检测到 Nerd Font 字体：" -ForegroundColor Green
    foreach ($font in $matchedFonts) {
        Write-Host " → $($font.Name) [$($font.Source)]" -ForegroundColor DarkGray
    }
}

Write-Host "`n===== 检查并安装 PSReadLine =====" -ForegroundColor Green
$moduleInstalled = Get-Module -ListAvailable -Name PSReadLine
if (-not $moduleInstalled) {
    Write-Host "未检测到 PSReadLine 模块，准备安装..." -ForegroundColor Yellow

    if ($isAdmin) {
        Write-Host "当前为管理员终端，安装 PSReadLine 到 AllUsers..." -ForegroundColor Cyan
        Install-Module PSReadLine -Scope AllUsers -Force -SkipPublisherCheck
    } else {
        Write-Host "当前为普通用户终端，安装 PSReadLine 到 CurrentUser..." -ForegroundColor Cyan
        Install-Module PSReadLine -Scope CurrentUser -Force -SkipPublisherCheck
    }

    Write-Host "✅ 安装完成！" -ForegroundColor Green
} else {
    Write-Host "✅ 已检测到 PSReadLine 模块，无需安装。" -ForegroundColor Green
}

if (-not $isAdmin) {
	Write-Host "`n===== 检查并安装 Scoop 软件 =====" -ForegroundColor Green
	if (!(Get-Command scoop -ErrorAction SilentlyContinue)) {
	    Write-Host "📦 Scoop 未安装，正在安装..."
	    Invoke-RestMethod -Uri https://get.scoop.sh | Invoke-Expression
	}
	
	# 添加 Scoop 的 main 仓库（如果未添加）
	if (-not (scoop bucket list | Select-String "main")) {
	    scoop bucket add main
	}
	
	# Scoop 软件列表
	$scoopPackages = @("eza", "ripgrep")
	foreach ($pkg in $scoopPackages) {
	    if (-not (scoop list | Select-String $pkg)) {
	        Write-Host "📦 安装 $pkg..."
	        scoop install $pkg
	    } else {
	        Write-Host "✅ $pkg 已安装，跳过"
	    }
	}
}

# .bashrc 风格的自动加载
# 需要的配置文件列表
$moduleList = @(
    "theme.ps1",        # 主题相关配置
    "history.ps1",      # 历史记录 & 语法高亮
    "keybindings.ps1",  # 快捷键 & 编辑模式
    "tools.ps1",        # 终端增强工具（zoxide 等）
    "aliases.ps1",      # 别名配置
    "functions.ps1",    # 自定义函数
    "devtools.ps1",     # 开发工具别名
    "extra.ps1"         # 其他扩展配置（可选）
)

# 配置模块的文件路径
Write-Host "`n===== 自动加载配置文件 =====" -ForegroundColor Green
$PSConfigPath = "$HOME\.powershell"
# 确保 $HOME\.powershell 目录存在
if (!(Test-Path $PSConfigPath)) {
    New-Item -ItemType Directory -Path $PSConfigPath -Force | Out-Null
    Write-Host "✅ 已创建 PowerShell 配置目录: $PSConfigPath"
} else {
    Write-Host "📂 PowerShell 配置目录已存在，跳过创建"
}

# 遍历创建文件（如果不存在）
foreach ($moduleName in $moduleList) {
    $moduleNamePath = Join-Path $PSConfigPath $moduleName
    if (!(Test-Path $moduleNamePath)) {
        New-Item -ItemType File -Path $moduleNamePath -Force | Out-Null
        Write-Host "📝 Created: $moduleNamePath"
    }
}

# 自动加载 .powershell 目录下的配置文件
foreach ($moduleName in $moduleList) {
    $moduleNamePath = Join-Path $PSConfigPath $moduleName
    if (Test-Path $moduleNamePath) {
        . $moduleNamePath
    }
}

Write-Host "PowerShell configuration loaded successfully!"
Write-Host "Current output encoding: $([Console]::OutputEncoding.EncodingName)"
'@

# 确保 $PROFILE 存在并写入内容
Set-Content -Path $PROFILE -Value $ProfileConfig

# 定义模块配置文件及内容
$files = @{
    "env.ps1" = @'
$start = Get-Date
Write-Host "🚀 开始加载 env 配置：$start" -ForegroundColor Cyan

# ========== 系统级环境变量 ==========

# 设置 JAVA_HOME
$javaPath = "C:\Program Files\Java\jdk-17"
if (Test-Path $javaPath) {
    Set-Item -Path "Env:JAVA_HOME" -Value $javaPath
    if (-not $env:Path.ToLower().Contains("$javaPath\bin".ToLower())) {
        $env:Path += ";$javaPath\bin"
    }
    Write-Host "✅ JAVA_HOME 设置为 $javaPath"
} else {
    Write-Warning "⚠️ 未找到 JAVA 路径：$javaPath"
}

# 设置 Qt 环境变量（推荐名称来自官方文档）
$qtDir = "C:\Qt\6.7.2\msvc2019_64"
$qtBin = "$qtDir\bin"
$qtPlugins = "$qtDir\plugins"
$qtPlatform = "$qtPlugins\platforms"
if (Test-Path $qtDir) {
    Set-Item -Path "Env:QTDIR" -Value $qtDir
    Set-Item -Path "Env:QT_PLUGIN_PATH" -Value $qtPlugins
    Set-Item -Path "Env:QT_QPA_PLATFORM_PLUGIN_PATH" -Value $qtPlatform
    if ((Test-Path $qtBin) -and ($env:Path -notlike "*$qtBin*")) {
        $env:Path += ";$qtBin"
    }
    Write-Host "✅ QTDIR 设置为 $qtDir"
    Write-Host "✅ QT_PLUGIN_PATH 设置为 $qtPlugins"
    Write-Host "✅ QT_QPA_PLATFORM_PLUGIN_PATH 设置为 $qtPlatform"
} else {
    Write-Warning "⚠️ 未找到 Qt 路径：$qtDir"
}

# ========== 用户级环境变量 ==========

# 设置 Python 开发环境
$pythonPath = "$env:USERPROFILE\AppData\Local\Programs\Python\Python312"
$pythonBin = "$pythonPath"
if (Test-Path $pythonPath) {
    Set-Item -Path "Env:PYTHON_HOME" -Value $pythonPath
    if ((Test-Path $pythonBin) -and ($env:Path -notlike "*$pythonBin*")) {
        $env:Path += ";$pythonBin;$pythonBin\Scripts"
    }
    Write-Host "✅ PYTHON_HOME 设置为 $pythonPath"
} else {
    Write-Warning "⚠️ 未找到 Python 路径：$pythonPath"
}

# 设置 Go 开发环境
$goRoot = "C:\Go"
$goPath = "$HOME\go"
$goBin = "$goRoot\bin"
$goPathBin = "$goPath\bin"
if (Test-Path $goRoot) {
    Set-Item -Path "Env:GOROOT" -Value $goRoot
    Set-Item -Path "Env:GOPATH" -Value $goPath
    if ((Test-Path $goBin) -and ($env:Path -notlike "*$goBin*")) {
        $env:Path += ";$goBin"
    }
    if ((Test-Path $goPathBin) -and ($env:Path -notlike "*$goPathBin*")) {
        $env:Path += ";$goPathBin"
    }
    Write-Host "✅ GOROOT 设置为 $goRoot"
    Write-Host "✅ GOPATH 设置为 $goPath"
} else {
    Write-Warning "⚠️ 未找到 Go 安装目录：$goRoot"
}

# 设置 Rust 环境（cargo）
$cargoBin = "$env:USERPROFILE\\.cargo\\bin"
if (Test-Path $cargoBin) {
    if ($env:Path -notlike "*$cargoBin*") {
        $env:Path += ";$cargoBin"
    }
    Write-Host "✅ Rust cargo 路径添加到 PATH：$cargoBin"
} else {
    Write-Warning "⚠️ 未找到 Rust cargo 路径：$cargoBin"
}

# 设置 Node.js 的路径（通常已自动配置）
$nodePath = "C:\Program Files\nodejs"
if (Test-Path "$nodePath\node.exe") {
    if ($env:Path -notlike "*$nodePath*") {
        $env:Path += ";$nodePath"
    }
    Write-Host "✅ Node.js 路径添加到 PATH：$nodePath"
} else {
    Write-Warning "⚠️ 未找到 Node.js：$nodePath"
}

# 设置 npm 的路径（通常已自动配置）
$npmGlobalPath = "$env:APPDATA\npm"
if (Test-Path $npmGlobalPath) {
    if ($env:Path -notlike "*$npmGlobalPath*") {
        $env:Path += ";$npmGlobalPath"
    }
    Write-Host "✅ npm 全局模块路径添加到 PATH：$npmGlobalPath"
} else {
    Write-Warning "⚠️ 未找到 npm 全局路径：$npmGlobalPath"
}

# 设置 .NET SDK 路径（dotnet）
$dotnetPath = "$env:ProgramFiles\\dotnet"
if (Test-Path $dotnetPath) {
    if ($env:Path -notlike "*$dotnetPath*") {
        $env:Path += ";$dotnetPath"
    }
    Write-Host "✅ .NET SDK 路径添加到 PATH：$dotnetPath"
} else {
    Write-Warning "⚠️ 未找到 .NET SDK 路径：$dotnetPath"
}

# 设置 Scoop 的 apps 路径
$scoopApps = "$env:USERPROFILE\\scoop\\shims"
if (Test-Path $scoopApps) {
    if ($env:Path -notlike "*$scoopApps*") {
        $env:Path += ";$scoopApps"
    }
    Write-Host "✅ Scoop 路径添加到 PATH：$scoopApps"
} else {
    Write-Warning "⚠️ 未找到 Scoop 应用路径：$scoopApps"
}

# WSL 子系统（不需设置 PATH，但可检查是否可用）
if (Get-Command wsl.exe -ErrorAction SilentlyContinue) {
    Write-Host "✅ 检测到 WSL 可用，输入 'wsl' 启动 Linux 子系统"
} else {
    Write-Warning "⚠️ 未检测到 WSL，请启用 Windows 子系统或安装 Linux 发行版"
}

# Anaconda 环境（默认安装位置）
$condaPath = "$env:USERPROFILE\anaconda3"
$condaBin = "$condaPath\Scripts"
if (Test-Path $condaPath) {
    Set-Item -Path "Env:CONDA_HOME" -Value $condaPath
    if ($env:Path -notlike "*$condaPath*") {
        $env:Path += ";$condaPath;$condaBin"
    }
    Write-Host "✅ Anaconda 环境已配置：$condaPath"
} else {
    Write-Warning "⚠️ 未找到 Anaconda 安装路径：$condaPath"
}

# 设置 JetBrains 系列（比如 PyCharm、CLion 等）
$jetBrainsBase = "$env:LOCALAPPDATA\Programs"
$jetBrainsProducts = @(
    "PyCharm Professional",
    "DataGrip",
    "DataSpell",
    "CLion",
    "IntelliJ IDEA Ultimate",
    "Android Studio"
)
foreach ($product in $jetBrainsProducts) {
    $binPath = "$jetBrainsBase\$product\bin"
    if (Test-Path $binPath) {
        if ($env:Path -notlike "*$binPath*") {
            $env:Path += ";$binPath"
        }
        Write-Host "✅ JetBrains [$product] 路径添加到 PATH：$binPath"
    } else {
        Write-Host "ℹ️ 可选 JetBrains 工具未安装：$product"
    }
}

# 自定义脚本路径（如有）
$customScripts = "$env:USERPROFILE\\scripts"
if (Test-Path $customScripts) {
    if ($env:Path -notlike "*$customScripts*") {
        $env:Path += ";$customScripts"
    }
    Write-Host "✅ Custom 脚本路径添加到 PATH：$customScripts"
} else {
    Write-Host "📁 尚未配置 custom 脚本目录，如需使用请创建：$customScripts"
}

$end = Get-Date
$duration = ($end - $start).TotalSeconds
Write-Host "✅ 环境变量加载完成，用时 $duration 秒`n" -ForegroundColor Green
'@;

    "aliases.ps1" = @'
$start = Get-Date
Write-Host "🚀 开始加载 aliases 配置：$start" -ForegroundColor Cyan

# 模拟 Linux 常用命令
Set-Alias ll Get-ChildItem
Set-Alias touch New-Item
Set-Alias grep Select-String
Set-Alias which Get-Command

$end = Get-Date
$duration = ($end - $start).TotalSeconds
Write-Host "✅ aliases 加载配置完成，用时 $duration 秒`n" -ForegroundColor Green
'@;

    "functions.ps1" = @'
$start = Get-Date
Write-Host "🚀 开始加载 functions 配置：$start" -ForegroundColor Cyan

# 在线命令解析
function explain {
    $cmd = $args -join "+"
    Invoke-RestMethod -Uri "https://cheat.sh/$cmd" -UseBasicParsing
}

# 自动升级所有软件
function UpdateAll {
    Write-Host "Updating Windows software using winget..."
    winget upgrade --all --silent
}

# 快速编辑配置文件
function edit-profile { notepad $PROFILE }

# 清空控制台和历史记录
function cls! {
    Clear-Host
    [System.Console]::Clear()
}

# 快速查看网络信息
function myip { Invoke-RestMethod ifconfig.me }

# 快速进入常用目录
function desk { Set-Location "$HOME\Desktop" }
function docs { Set-Location "$HOME\Documents" }
function proj { Set-Location "$HOME\Documents\Projects" }
function scripts { Set-Location "$HOME\Documents\Scripts" }
function downloads { Set-Location "$HOME\Downloads" }

# Winget 安装和搜索软件 
function install { param($pkg) winget install $pkg }
function searchpkg { param($name) winget search $name }

# 查看系统信息
function sysinfo {
    Get-ComputerInfo | Select-Object OsName, OsArchitecture, CsTotalPhysicalMemory, WindowsProductName, OsVersion
}

# 检查网络连通性
function pingtest {
    Test-Connection -ComputerName 8.8.8.8 -Count 4
}

# 清理回收站
function empty-trash {
    Clear-RecycleBin -Force
}

# 快速测试端口是否开放
function test-port {
    param (
        [string]$host,
        [int]$port
    )
    Test-NetConnection -ComputerName $host -Port $port
}

# 搜索文件内容
function find-text {
    param($text, $path = ".")
    Get-ChildItem -Recurse -File -Path $path | Select-String -Pattern $text
}

$end = Get-Date
$duration = ($end - $start).TotalSeconds
Write-Host "✅ functions 加载配置完成，用时 $duration 秒`n" -ForegroundColor Green
'@;

    "history.ps1" = @'
$start = Get-Date
Write-Host "🚀 开始加载 history 配置：$start" -ForegroundColor Cyan

# 启用语法高亮（自定义颜色）
Set-PSReadLineOption -Colors @{ "Command" = "DarkYellow" }

# 启用历史预测、Tab 补全 & 搜索优化
# InlineView和ListView二选一。如果喜欢像 GitHub Copilot 的灰色提示，建议使用 InlineView；如果喜欢候选列表样式，用 ListView。
Set-PSReadLineOption -PredictionSource History
Set-PSReadLineOption -PredictionViewStyle ListView
Set-PSReadLineOption -HistorySearchCursorMovesToEnd

# 持久化历史记录（自动保存）
Set-PSReadLineOption -HistorySaveStyle SaveIncrementally

# 增加历史记录条数 & 避免重复项
# Set-PSReadLineOption -MaximumHistoryCount 30
# Set-PSReadLineOption -HistoryNoDuplicates

$end = Get-Date
$duration = ($end - $start).TotalSeconds
Write-Host "✅ history 加载配置完成，用时 $duration 秒`n" -ForegroundColor Green
'@;

    "keybindings.ps1" = @'
$start = Get-Date
Write-Host "🚀 开始加载 keybindings 配置：$start" -ForegroundColor Cyan

# 设置编辑模式为 Emacs or Vi（更常见的按键逻辑）
Set-PSReadLineOption -EditMode Emacs

# 实用快捷键映射
Set-PSReadLineKeyHandler -Key Ctrl+l -Function ClearScreen
Set-PSReadLineKeyHandler -Key Ctrl+r -Function ReverseSearchHistory

$end = Get-Date
$duration = ($end - $start).TotalSeconds
Write-Host "✅ keybindings 加载配置完成，用时 $duration 秒`n" -ForegroundColor Green
'@;

    "theme.ps1" = @'
$start = Get-Date
Write-Host "🚀 开始加载 theme 配置：$start" -ForegroundColor Cyan

# 设置主题
$themePath = "$env:POSH_THEMES_PATH\powerlevel10k_rainbow.omp.json"
if (Test-Path $themePath) {
    oh-my-posh init pwsh --config $themePath | Invoke-Expression
} else {
    Write-Warning "⚠️ 未找到指定主题配置文件：$themePath"
}

$end = Get-Date
$duration = ($end - $start).TotalSeconds
Write-Host "✅ theme 加载配置完成，用时 $duration 秒`n" -ForegroundColor Green
'@;

    "tools.ps1" = @'
$start = Get-Date
Write-Host "🚀 开始加载 tools 配置：$start" -ForegroundColor Cyan

# 配置 zoxide （更强大的 cd 命令）
Invoke-Expression (& { (zoxide init powershell) -join "`n" })

$end = Get-Date
$duration = ($end - $start).TotalSeconds
Write-Host "✅ tools 加载配置完成，用时 $duration 秒`n" -ForegroundColor Green
'@;

    "extra.ps1" = @'
$start = Get-Date
Write-Host "🚀 开始加载 extra 配置：$start" -ForegroundColor Cyan

# 模拟 Linux 提权命令 
Set-Alias sudo gsudo

$end = Get-Date
$duration = ($end - $start).TotalSeconds
Write-Host "✅ extra 加载配置完成，用时 $duration 秒`n" -ForegroundColor Green
'@;

    "devtools.ps1" = @'
$start = Get-Date
Write-Host "🚀 开始加载 devtools 配置：$start" -ForegroundColor Cyan

$end = Get-Date
$duration = ($end - $start).TotalSeconds
Write-Host "✅ devtools 加载配置完成，用时 $duration 秒`n" -ForegroundColor Green
'@
}

# 遍历写入每个配置文件
foreach ($file in $files.Keys) {
    $filePath = "$PSConfigPath\$file"
    
    # 确保文件目录存在
    if (!(Test-Path $PSConfigPath)) {
        New-Item -ItemType Directory -Path $PSConfigPath -Force | Out-Null
    }

    # 写入文件（覆盖旧内容，确保完整写入）
    Set-Content -Path $filePath -Value $files[$file]
    Write-Host "✅ 配置文件写入成功: $filePath"
}

Write-Host "✅ 所有 PowerShell 配置文件已完成！"
Write-Host "`n是否现在加载新的配置文件？输入 Y 应用，其他键跳过：" -NoNewline
$apply = Read-Host
if ($apply -match '^[Yy]$') {
    . $PROFILE
    Write-Host "✅ 新配置已生效！" -ForegroundColor Green
} else {
    Write-Host "⏭️ 已跳过，请手动执行：. `$PROFILE" -ForegroundColor Yellow
}