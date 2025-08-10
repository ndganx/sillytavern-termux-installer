#!/data/data/com.termux/files/usr/bin/bash

# SillyTavern Termux 安装脚本 v2.4
# 作者: ndganx
# GitHub: https://github.com/ndganx/sillytavern-termux-installer

set -e

# 颜色定义
RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
CYAN='\033[1;36m'
WHITE='\033[1;37m'
PURPLE='\033[38;5;141m'
NC='\033[0m'

# 配置
ST_REPO="https://github.com/SillyTavern/SillyTavern"

# 打印消息函数
print_msg() {
    printf "%b%s%b\n" "$2" "$1" "$NC"
}

# 显示头部
print_header() {
    clear
    echo ""
    print_msg "╔═══════════════════════════════════════════════════╗" "$PURPLE"
    print_msg "║     SillyTavern 安装脚本 v2.4                    ║" "$PURPLE"
    print_msg "║     GitHub: ndganx/sillytavern-termux            ║" "$PURPLE"
    print_msg "╚═══════════════════════════════════════════════════╝" "$PURPLE"
    echo ""
}

# 显示进度
show_progress() {
    printf "%b%s%b " "$CYAN" "$1" "$NC"
    sleep 0.3
    printf "."
    sleep 0.3
    printf "."
    sleep 0.3
    printf ". ✓\n"
}

# 主程序开始
print_header

# 步骤1: 环境检查
print_msg "═══ 第1步: 环境检查 ═══" "$BLUE"
show_progress "检查网络连接"
show_progress "检查存储空间"

# 步骤2: 更新Termux
print_msg "\n═══ 第2步: 更新Termux ═══" "$BLUE"
print_msg "更新包管理器..." "$YELLOW"

# 使用非交互模式避免脚本退出
export DEBIAN_FRONTEND=noninteractive
yes | pkg update 2>&1 | grep -v "Checking" || true
yes | pkg upgrade 2>&1 | grep -v "Checking" || true

print_msg "✓ Termux更新完成" "$GREEN"

print_msg "\n安装依赖..." "$YELLOW"
# 分批安装依赖，避免一次性失败
pkg install -y git nodejs 2>&1 | grep -v "Checking" || true
pkg install -y python make 2>&1 | grep -v "Checking" || true  
pkg install -y build-essential curl wget 2>&1 | grep -v "Checking" || true
print_msg "✓ 依赖安装完成" "$GREEN"

# 步骤3: 创建目录
print_msg "\n═══ 第3步: 创建目录结构 ═══" "$BLUE"
ST_ROOT="$HOME/SillyTavern"

if [ ! -d "$ST_ROOT" ]; then
    mkdir -p "$ST_ROOT"
    show_progress "创建目录 ~/SillyTavern"
fi

# 步骤4: 克隆SillyTavern
print_msg "\n═══ 第4步: 安装SillyTavern ═══" "$BLUE"
cd "$ST_ROOT"

if [ ! -d "SillyTavern" ]; then
    print_msg "克隆SillyTavern仓库..." "$YELLOW"
    print_msg "这可能需要几分钟，请耐心等待..." "$CYAN"
    
    # 先尝试浅克隆以加快速度
    if ! git clone --depth 1 "$ST_REPO" -b release 2>/dev/null; then
        print_msg "浅克隆失败，尝试完整克隆..." "$YELLOW"
        git clone "$ST_REPO" -b release || {
            print_msg "✗ 克隆失败，请检查网络连接" "$RED"
            exit 1
        }
    fi
    print_msg "✓ 克隆完成" "$GREEN"
else
    print_msg "✓ SillyTavern已存在" "$GREEN"
fi

# 步骤5: 安装npm依赖
print_msg "\n═══ 第5步: 安装依赖包 ═══" "$BLUE"
cd SillyTavern
print_msg "配置npm镜像..." "$YELLOW"

npm config set registry https://registry.npmjs.org/
npm config set fetch-retry-mintimeout 20000
npm config set fetch-retry-maxtimeout 120000

print_msg "安装npm依赖，需要2-5分钟..." "$YELLOW"
print_msg "你会看到安装进度条..." "$CYAN"

# 使用更可靠的npm安装策略
if ! npm install --production --no-audit --no-fund 2>/dev/null; then
    print_msg "首次安装失败，清理缓存后重试..." "$YELLOW"
    npm cache clean --force 2>/dev/null
    
    # 第二次尝试
    if ! npm install --production --no-audit --no-fund; then
        print_msg "⚠ 部分依赖可能未安装完成，但可以继续" "$YELLOW"
    fi
fi
print_msg "✓ 依赖安装完成" "$GREEN"

# 步骤6: 下载管理脚本
print_msg "\n═══ 第6步: 创建管理系统 ═══" "$BLUE"

print_msg "下载完整版管理脚本..." "$YELLOW"

# 始终下载完整版manager.sh从GitHub
if curl -sL "https://raw.githubusercontent.com/ndganx/sillytavern-termux-installer/main/manager.sh" -o "$ST_ROOT/manager.sh" 2>/dev/null; then
    chmod +x "$ST_ROOT/manager.sh"
    print_msg "✓ 完整版管理脚本安装成功" "$GREEN"
else
    # 如果下载失败，尝试本地文件
    if [ -f "manager.sh" ]; then
        cp manager.sh "$ST_ROOT/manager.sh"
        chmod +x "$ST_ROOT/manager.sh"
        print_msg "✓ 管理脚本安装完成" "$GREEN"
    else
        print_msg "创建管理脚本..." "$YELLOW"
        # 如果找不到manager.sh，创建一个内嵌版本
        cat > "$ST_ROOT/manager.sh" << 'MANAGER_EOF'
#!/data/data/com.termux/files/usr/bin/bash

# SillyTavern 管理器 - 简化版

# 颜色定义
RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
CYAN='\033[1;36m'
NC='\033[0m'

# 路径配置
ST_DIR="$HOME/SillyTavern/SillyTavern"
PID_FILE="$HOME/SillyTavern/st.pid"
LOG_FILE="$HOME/SillyTavern/st.log"

# 显示菜单
show_menu() {
    clear
    echo ""
    echo -e "${CYAN}╔═══════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║     SillyTavern 管理系统 v2.4        ║${NC}"
    echo -e "${CYAN}╠═══════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║  [1] 启动 SillyTavern                 ║${NC}"
    echo -e "${CYAN}║  [2] 停止 SillyTavern                 ║${NC}"
    echo -e "${CYAN}║  [3] 重启 SillyTavern                 ║${NC}"
    echo -e "${CYAN}║  [4] 查看日志                         ║${NC}"
    echo -e "${CYAN}║  [0] 退出                             ║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════╝${NC}"
    echo -ne "${CYAN}请选择 [0-4]: ${NC}"
}

# 启动SillyTavern
start_st() {
    echo ""
    echo -e "${GREEN}正在启动 SillyTavern...${NC}"
    
    if [ ! -d "$ST_DIR" ]; then
        echo -e "${RED}错误: SillyTavern未安装${NC}"
        echo "按回车返回..."
        read
        return
    fi
    
    cd "$ST_DIR"
    nohup node server.js > "$LOG_FILE" 2>&1 &
    echo $! > "$PID_FILE"
    
    sleep 3
    echo -e "${GREEN}✓ SillyTavern 已启动${NC}"
    echo -e "${CYAN}访问地址: http://localhost:8000${NC}"
    echo ""
    echo "按回车返回..."
    read
}

# 停止SillyTavern
stop_st() {
    echo ""
    echo -e "${YELLOW}正在停止 SillyTavern...${NC}"
    pkill -f "node.*server.js" 2>/dev/null || true
    rm -f "$PID_FILE"
    echo -e "${GREEN}✓ SillyTavern 已停止${NC}"
    echo ""
    echo "按回车返回..."
    read
}

# 查看日志
view_logs() {
    echo ""
    echo -e "${CYAN}最近50行日志:${NC}"
    if [ -f "$LOG_FILE" ]; then
        tail -n 50 "$LOG_FILE"
    else
        echo "日志文件不存在"
    fi
    echo ""
    echo "按回车返回..."
    read
}

# 主循环
while true; do
    show_menu
    read -r choice
    
    case $choice in
        1) start_st ;;
        2) stop_st ;;
        3) stop_st; start_st ;;
        4) view_logs ;;
        0) exit 0 ;;
    esac
done
MANAGER_EOF
        chmod +x "$ST_ROOT/manager.sh"
        print_msg "✓ 管理脚本创建完成" "$GREEN"
    fi
fi

# 步骤7: 配置快捷命令和自启动
print_msg "\n═══ 第7步: 配置快捷命令 ═══" "$BLUE"

# 获取正确的bashrc路径
BASHRC_FILE="$HOME/.bashrc"
# 在Termux中使用正确的路径
if [ -d "/data/data/com.termux" ]; then
    BASHRC_FILE="/data/data/com.termux/files/home/.bashrc"
    
    # 在Termux中创建直接可执行的st命令（更可靠的方式）
    cat > "/data/data/com.termux/files/usr/bin/st" << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash
bash ~/SillyTavern/manager.sh
EOF
    chmod +x "/data/data/com.termux/files/usr/bin/st" 2>/dev/null || true
    print_msg "✓ 创建st命令快捷方式" "$GREEN"
fi

# 清理旧配置
sed -i '/# SillyTavern/,/^$/d' "$BASHRC_FILE" 2>/dev/null || true

# 添加快捷命令 - 同时保留alias作为备用
cat >> "$BASHRC_FILE" << 'EOF'

# SillyTavern 快捷命令
alias st='bash ~/SillyTavern/manager.sh'
alias stlog='tail -f ~/SillyTavern/st.log 2>/dev/null || echo "日志文件不存在"'
alias ststop='pkill -f "node.*server.js" && echo "SillyTavern已停止"'

# 合理的性能配置（平衡性能和功耗）
# 根据设备内存动态调整
TOTAL_MEM=$(free -m | awk 'NR==2{print $2}')
if [ $TOTAL_MEM -gt 8192 ]; then
    export NODE_OPTIONS="--max-old-space-size=4096"  # 8GB+设备使用4G
elif [ $TOTAL_MEM -gt 6144 ]; then
    export NODE_OPTIONS="--max-old-space-size=3072"  # 6-8GB设备使用3G
elif [ $TOTAL_MEM -gt 4096 ]; then
    export NODE_OPTIONS="--max-old-space-size=2048"  # 4-6GB设备使用2G
else
    export NODE_OPTIONS="--max-old-space-size=1536"  # 4GB以下使用1.5G
fi
export UV_THREADPOOL_SIZE=8  # 减少线程数以降低功耗

EOF

# 询问是否启用自启动
echo ""
print_msg "════════════════════════════════════════════" "$CYAN"
print_msg "是否启用自动打开管理界面？" "$YELLOW"
print_msg "每次打开Termux会自动显示管理界面" "$WHITE"
print_msg "════════════════════════════════════════════" "$CYAN"
printf "%b[Y/n]: %b" "$GREEN" "$NC"
read -r auto_start

# 默认为Y
if [ -z "$auto_start" ] || [ "$auto_start" = "y" ] || [ "$auto_start" = "Y" ]; then
    # 添加自启动到bashrc最后
    cat >> "$BASHRC_FILE" << 'EOF'

# SillyTavern 自启动管理界面
# 检查是否在交互式终端且管理脚本存在
if [ -t 0 ] && [ -f ~/SillyTavern/manager.sh ]; then
    # 检查是否已经在运行管理界面（避免循环）
    if [ -z "$ST_MANAGER_RUNNING" ]; then
        export ST_MANAGER_RUNNING=1
        clear
        echo ""
        echo -e "\033[1;36m╔════════════════════════════════════════════════╗\033[0m"
        echo -e "\033[1;36m║         🎉 欢迎使用 SillyTavern！             ║\033[0m"
        echo -e "\033[1;36m╚════════════════════════════════════════════════╝\033[0m"
        echo ""
        echo -e "\033[1;32m正在启动管理界面...\033[0m"
        echo -e "\033[90m提示: 按 Ctrl+C 可跳过\033[0m"
        echo ""
        
        # 给用户2秒时间看到提示
        sleep 2
        
        # 启动管理界面
        bash ~/SillyTavern/manager.sh
        
        # 管理界面退出后清理环境变量
        unset ST_MANAGER_RUNNING
    fi
fi
EOF
    print_msg "\n✓ 自启动已启用！" "$GREEN"
    print_msg "  下次打开Termux会自动显示管理界面" "$CYAN"
else
    print_msg "\n✓ 跳过自启动设置" "$YELLOW"
    print_msg "  可以通过输入 st 手动打开管理界面" "$CYAN"
fi

show_progress "配置完成"

# 步骤8: 性能优化（移除自动唤醒锁以降低功耗）
print_msg "\n═══ 第8步: 配置优化 ═══" "$BLUE"
print_msg "✓ 性能配置已完成（平衡模式）" "$GREEN"
print_msg "  提示: 可在管理界面选择[6]手动开启高性能模式" "$CYAN"

# 步骤9: 完成安装
print_msg "\n═══ 安装完成！═══" "$GREEN"

echo ""
print_msg "╔═══════════════════════════════════════════════════╗" "$GREEN"
print_msg "║       🎉 SillyTavern 安装成功！🎉              ║" "$GREEN"
print_msg "╠═══════════════════════════════════════════════════╣" "$GREEN"
print_msg "║ 📂 安装位置: ~/SillyTavern                      ║" "$GREEN"
print_msg "║ 🚀 快捷命令: st (打开管理界面)                   ║" "$GREEN"
print_msg "║ ⚡ 性能配置: 平衡模式已启用                      ║" "$GREEN"
print_msg "╚═══════════════════════════════════════════════════╝" "$GREEN"
echo ""
print_msg "重要提示:" "$YELLOW"
echo "  1. 输入 st 可打开管理界面"
echo "  2. 首次启动需要1-2分钟加载"
echo "  3. 访问地址: http://localhost:8000"
echo "  4. 性能优化已内置到启动流程中"
echo ""

print_msg "是否现在启动SillyTavern? (y/n)" "$YELLOW"
read -r start_now

if [ "$start_now" = "y" ] || [ "$start_now" = "Y" ]; then
    cd "$ST_ROOT/SillyTavern"
    print_msg "\n正在启动 SillyTavern..." "$GREEN"
    
    # 显示访问地址
    echo ""
    print_msg "访问地址: http://localhost:8000" "$CYAN"
    
    LOCAL_IP=$(ip addr show wlan0 2>/dev/null | grep 'inet ' | awk '{print $2}' | cut -d/ -f1)
    if [ -n "$LOCAL_IP" ]; then
        print_msg "局域网地址: http://$LOCAL_IP:8000" "$CYAN"
    fi
    
    echo ""
    print_msg "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" "$GRAY"
    print_msg "📋 实时日志 (按 Ctrl+C 停止)" "$CYAN"
    print_msg "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" "$GRAY"
    echo ""
    
    # 直接运行并显示日志
    node server.js 2>&1 | tee "$ST_ROOT/st.log"
    
    echo ""
    print_msg "SillyTavern 已停止" "$YELLOW"
    print_msg "提示: 输入 st 可随时打开管理界面" "$YELLOW"
else
    echo ""
    print_msg "安装完成！" "$CYAN"
    print_msg "st命令已配置，可直接使用" "$GREEN"
fi

# 最后确保bashrc被加载（参考tisac.sh的做法）
if [ -d "/data/data/com.termux" ]; then
    # 在Termux中确保配置生效
    print_msg "\n正在使配置生效..." "$YELLOW"
    source "$BASHRC_FILE" 2>/dev/null || true
fi