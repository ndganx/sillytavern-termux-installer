#!/data/data/com.termux/files/usr/bin/bash

# SillyTavern 管理器 v2.6 - 完整功能版
# 作者: ndganx
# GitHub: https://github.com/ndganx/sillytavern-termux-installer

# 颜色定义
RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
CYAN='\033[1;36m'
MAGENTA='\033[1;35m'
WHITE='\033[1;37m'
GRAY='\033[90m'
NC='\033[0m'

# 路径配置
ST_ROOT="$HOME/SillyTavern"
ST_DIR="$ST_ROOT/SillyTavern"
PID_FILE="$ST_ROOT/st.pid"
LOG_FILE="$ST_ROOT/st.log"
BACKUP_DIR="$ST_ROOT/backups"

# 性能配置 - 合理配置，避免耗电
# 根据内存动态调整，使用合理的值
TOTAL_MEM=$(free -m | awk 'NR==2{print $2}' 2>/dev/null || echo 2048)
if [ "$TOTAL_MEM" -gt 8192 ]; then
    export NODE_OPTIONS="--max-old-space-size=4096"  # 8GB+设备用4G
    export UV_THREADPOOL_SIZE=8                      # 8线程
elif [ "$TOTAL_MEM" -gt 4096 ]; then
    export NODE_OPTIONS="--max-old-space-size=2048"  # 4-8GB设备用2G
    export UV_THREADPOOL_SIZE=4                      # 4线程
else
    export NODE_OPTIONS="--max-old-space-size=1024"  # 4GB以下用1G
    export UV_THREADPOOL_SIZE=2                      # 2线程
fi

# 其他低耗电优化
export NODE_ENV="production"                         # 生产模式，减少调试开销
export NODE_NO_WARNINGS=1                            # 减少警告输出
export NODE_CLUSTER_SCHED_POLICY="rr"               # 轮询调度，更均衡

# 确保目录存在
mkdir -p "$ST_ROOT" "$BACKUP_DIR" 2>/dev/null

# 获取版本信息
get_versions() {
    if [ -d "$ST_DIR" ]; then
        cd "$ST_DIR"
        
        # 获取本地版本信息
        LOCAL_VERSION=$(grep '"version"' package.json 2>/dev/null | awk -F '"' '{print $4}' || echo "unknown")
        LOCAL_HASH=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
        LOCAL_BRANCH=$(git branch --show-current 2>/dev/null || echo "unknown")
        
        # 判断分支类型
        if [ "$LOCAL_BRANCH" = "release" ]; then
            BRANCH_TYPE="release"
        elif [ "$LOCAL_BRANCH" = "staging" ]; then
            BRANCH_TYPE="staging"
        else
            BRANCH_TYPE="$LOCAL_BRANCH"
        fi
        
        # 当前版本格式：版本号 [哈希] (分支类型)
        CURRENT_VERSION="$LOCAL_VERSION [$LOCAL_HASH] ($BRANCH_TYPE)"
    else
        CURRENT_VERSION="未安装"
    fi
    
    # 获取最新版本信息
    LATEST_VERSION="检查中..."
    
    # 缓存文件
    CACHE_FILE="$ST_ROOT/.version_cache"
    
    # 检查缓存（5分钟有效）
    if [ -f "$CACHE_FILE" ] && [ $(($(date +%s) - $(stat -c %Y "$CACHE_FILE" 2>/dev/null || echo 0))) -lt 300 ]; then
        LATEST_VERSION=$(cat "$CACHE_FILE")
    else
        # 获取最新release版本
        LATEST_DATA=$(curl -s https://api.github.com/repos/SillyTavern/SillyTavern/releases/latest 2>/dev/null)
        if [ -n "$LATEST_DATA" ]; then
            LATEST_TAG=$(echo "$LATEST_DATA" | grep '"tag_name"' | head -1 | awk -F '"' '{print $4}' | sed 's/^v//')
            
            # 尝试获取commit hash
            if [ -d "$ST_DIR" ]; then
                cd "$ST_DIR"
                git fetch origin release --quiet 2>/dev/null
                LATEST_HASH=$(git rev-parse --short origin/release 2>/dev/null || echo "unknown")
            else
                LATEST_HASH="unknown"
            fi
            
            if [ -n "$LATEST_TAG" ]; then
                LATEST_VERSION="$LATEST_TAG [$LATEST_HASH] (release)"
                echo "$LATEST_VERSION" > "$CACHE_FILE"
            else
                LATEST_VERSION="获取失败"
            fi
        else
            LATEST_VERSION="获取失败"
        fi
    fi
}

# 检查状态
check_status() {
    if [ -f "$PID_FILE" ]; then
        PID=$(cat "$PID_FILE" 2>/dev/null)
        if [ -n "$PID" ] && kill -0 "$PID" 2>/dev/null; then
            STATUS="${GREEN}● 运行中${NC}"
            return 0
        fi
    fi
    STATUS="${RED}● 已停止${NC}"
    return 1
}

# 显示主菜单
show_menu() {
    clear
    get_versions
    check_status
    
    echo ""
    echo -e "${CYAN}╔═══════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║       SillyTavern 管理系统 v2.6                  ║${NC}"
    echo -e "${CYAN}╠═══════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${NC} 状态: $STATUS                                    ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC} 当前版本: ${WHITE}$CURRENT_VERSION${NC}"
    echo -e "${CYAN}║${NC} 最新版本: ${GREEN}$LATEST_VERSION${NC}"
    echo -e "${CYAN}╠═══════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║  [1]${NC} 🚀 启动 SillyTavern                          ${CYAN}║${NC}"
    echo -e "${CYAN}║  [2]${NC} 🛑 停止 SillyTavern                          ${CYAN}║${NC}"
    echo -e "${CYAN}║  [3]${NC} 🔄 重启 SillyTavern                          ${CYAN}║${NC}"
    echo -e "${CYAN}║  [4]${NC} ⬆️  更新 SillyTavern                          ${CYAN}║${NC}"
    echo -e "${CYAN}║  [5]${NC} 📋 查看实时日志                              ${CYAN}║${NC}"
    echo -e "${CYAN}║  [6]${NC} 💾 备份用户数据                              ${CYAN}║${NC}"
    echo -e "${CYAN}║  [7]${NC} 📥 恢复用户数据                              ${CYAN}║${NC}"
    echo -e "${CYAN}║  [8]${NC} 🔧 一键全面更新                              ${CYAN}║${NC}"
    echo -e "${CYAN}║  [9]${NC} ℹ️  系统信息                                  ${CYAN}║${NC}"
    echo -e "${CYAN}║  [0]${NC} 👋 退出                                      ${CYAN}║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════╝${NC}"
    echo -ne "${WHITE}请选择 [0-9]: ${NC}"
}

# 启动SillyTavern
start_st() {
    check_status
    if [ $? -eq 0 ]; then
        echo ""
        echo -e "${YELLOW}⚠️  SillyTavern 已在运行中${NC}"
        echo -e "${GREEN}访问地址: http://localhost:8000${NC}"
        echo ""
        echo "按回车返回..."
        read
        return
    fi
    
    if [ ! -d "$ST_DIR" ]; then
        echo ""
        echo -e "${RED}❌ 错误: SillyTavern未安装${NC}"
        echo -e "${YELLOW}请先运行安装脚本${NC}"
        echo ""
        echo "按回车返回..."
        read
        return
    fi
    
    echo ""
    echo -e "${GREEN}🚀 正在启动 SillyTavern...${NC}"
    echo ""
    
    # 启动前自动进行系统优化
    echo -e "${CYAN}正在进行启动前优化...${NC}"
    
    # 1. 清理npm缓存（如果需要）
    if [ -d "$ST_DIR/node_modules" ]; then
        MODULES_SIZE=$(du -sm "$ST_DIR/node_modules" 2>/dev/null | awk '{print $1}')
        if [ "$MODULES_SIZE" -gt 500 ]; then
            echo "  清理npm缓存..."
            npm cache clean --force 2>/dev/null
            echo "  ✅ 缓存已清理"
        fi
    fi
    
    # 2. 清理日志文件（如果太大）
    if [ -f "$LOG_FILE" ]; then
        LOG_SIZE=$(du -m "$LOG_FILE" 2>/dev/null | awk '{print $1}')
        if [ "$LOG_SIZE" -gt 10 ]; then
            echo "  清理过大的日志文件..."
            > "$LOG_FILE"
            echo "  ✅ 日志已清理"
        fi
    fi
    
    # 3. 设置合理的性能参数（已在文件开头设置）
    echo "  ✅ 性能参数已优化"
    echo ""
    
    cd "$ST_DIR"
    
    # 检查node是否存在
    if ! command -v node >/dev/null 2>&1; then
        echo -e "${YELLOW}⚠️  Node.js未安装，正在安装...${NC}"
        pkg install nodejs -y
    fi
    
    nohup node server.js > "$LOG_FILE" 2>&1 &
    echo $! > "$PID_FILE"
    
    # 真实检测服务是否启动成功
    echo "等待服务启动..."
    MAX_WAIT=30  # 最多等待30秒
    WAIT_COUNT=0
    
    # 显示进度条
    while [ $WAIT_COUNT -lt $MAX_WAIT ]; do
        # 检查8000端口是否已经打开
        if curl -s -o /dev/null -w "%{http_code}" http://localhost:8000 2>/dev/null | grep -q "200\|301\|302"; then
            echo ""
            echo -e "${GREEN}✅ SillyTavern 启动成功！${NC}"
            break
        fi
        
        # 检查进程是否还在运行
        if [ -f "$PID_FILE" ]; then
            PID=$(cat "$PID_FILE")
            if ! kill -0 "$PID" 2>/dev/null; then
                echo ""
                echo -e "${RED}❌ 启动失败，请查看日志${NC}"
                tail -n 20 "$LOG_FILE"
                echo ""
                echo "按回车返回..."
                read
                return
            fi
        fi
        
        # 显示进度
        printf "."
        sleep 1
        WAIT_COUNT=$((WAIT_COUNT + 1))
    done
    
    if [ $WAIT_COUNT -ge $MAX_WAIT ]; then
        echo ""
        echo -e "${YELLOW}⚠️  启动超时，但进程可能仍在运行${NC}"
        echo "请稍后手动访问 http://localhost:8000"
    else
        # 启动成功，显示访问地址
        echo ""
        echo -e "${CYAN}📱 访问方式：${NC}"
        echo -e "   本地访问: ${WHITE}http://localhost:8000${NC}"
        
        # 获取局域网IP
        IP=$(ip addr show wlan0 2>/dev/null | grep 'inet ' | awk '{print $2}' | cut -d/ -f1)
        if [ -n "$IP" ]; then
            echo -e "   局域网访问: ${WHITE}http://$IP:8000${NC}"
        fi
        
        # 自动打开浏览器
        echo ""
        echo -e "${CYAN}正在打开浏览器...${NC}"
        
        # Termux特有的打开浏览器方法
        if command -v termux-open-url >/dev/null 2>&1; then
            termux-open-url "http://localhost:8000" 2>/dev/null || true
        elif command -v am >/dev/null 2>&1; then
            # Android Activity Manager方式
            am start -a android.intent.action.VIEW -d "http://localhost:8000" 2>/dev/null || true
        elif command -v xdg-open >/dev/null 2>&1; then
            # 通用Linux方式
            xdg-open "http://localhost:8000" 2>/dev/null || true
        fi
        
        echo -e "${GREEN}✨ 浏览器已打开，请查看${NC}"
    fi
    
    echo ""
    echo "按回车返回..."
    read
}

# 停止SillyTavern
stop_st() {
    echo ""
    echo -e "${YELLOW}正在停止 SillyTavern...${NC}"
    
    if [ -f "$PID_FILE" ]; then
        PID=$(cat "$PID_FILE" 2>/dev/null)
        if [ -n "$PID" ]; then
            kill "$PID" 2>/dev/null || true
            rm -f "$PID_FILE"
        fi
    fi
    
    pkill -f "node.*server.js" 2>/dev/null || true
    
    echo -e "${GREEN}✅ SillyTavern 已停止${NC}"
    echo ""
    echo "按回车返回..."
    read
}

# 更新SillyTavern
update_st() {
    echo ""
    echo -e "${CYAN}╔═══════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║             ⬆️  更新 SillyTavern                    ║${NC}"
    echo -e "${CYAN}╠═══════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║  [1] 快速更新 (git pull)                          ║${NC}"
    echo -e "${CYAN}║  [2] 更新到最新正式版 (release)                   ║${NC}"
    echo -e "${CYAN}║  [3] 更新到测试版 (staging)                       ║${NC}"
    echo -e "${CYAN}║  [0] 返回主菜单                                   ║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════╝${NC}"
    echo -ne "请选择 [0-3]: "
    
    read choice
    
    if [ "$choice" = "0" ]; then
        return
    fi
    
    if [ ! -d "$ST_DIR" ]; then
        echo -e "${RED}错误: SillyTavern未安装${NC}"
        echo "按回车返回..."
        read
        return
    fi
    
    case $choice in
        1)
            echo ""
            echo -e "${YELLOW}执行快速更新...${NC}"
            cd "$ST_DIR"
            git pull
            npm install --production --no-audit --no-fund
            echo -e "${GREEN}✅ 更新完成${NC}"
            ;;
            
        2|3)
            if [ "$choice" = "2" ]; then
                BRANCH="release"
                echo -e "${GREEN}更新到正式版...${NC}"
            else
                BRANCH="staging"
                echo -e "${YELLOW}更新到测试版...${NC}"
            fi
            
            # 备份用户数据
            echo "备份用户数据..."
            TEMP_BACKUP="$ST_ROOT/temp_backup_$(date +%Y%m%d_%H%M%S)"
            mkdir -p "$TEMP_BACKUP"
            
            [ -d "$ST_DIR/data" ] && cp -r "$ST_DIR/data" "$TEMP_BACKUP/"
            [ -d "$ST_DIR/public/characters" ] && cp -r "$ST_DIR/public/characters" "$TEMP_BACKUP/"
            [ -d "$ST_DIR/public/User Avatars" ] && cp -r "$ST_DIR/public/User Avatars" "$TEMP_BACKUP/"
            [ -f "$ST_DIR/config.yaml" ] && cp "$ST_DIR/config.yaml" "$TEMP_BACKUP/"
            
            # 备份并删除旧版本
            OLD_DIR="$ST_DIR.backup.$(date +%Y%m%d_%H%M%S)"
            mv "$ST_DIR" "$OLD_DIR"
            
            # 克隆新版本
            echo "下载新版本..."
            git clone https://github.com/SillyTavern/SillyTavern -b "$BRANCH" "$ST_DIR"
            
            # 恢复用户数据
            echo "恢复用户数据..."
            [ -d "$TEMP_BACKUP/data" ] && cp -r "$TEMP_BACKUP/data" "$ST_DIR/"
            [ -d "$TEMP_BACKUP/characters" ] && cp -r "$TEMP_BACKUP/characters" "$ST_DIR/public/"
            [ -d "$TEMP_BACKUP/User Avatars" ] && cp -r "$TEMP_BACKUP/User Avatars" "$ST_DIR/public/"
            [ -f "$TEMP_BACKUP/config.yaml" ] && cp "$TEMP_BACKUP/config.yaml" "$ST_DIR/"
            
            # 安装依赖
            cd "$ST_DIR"
            npm install --production --no-audit --no-fund
            
            # 清理
            rm -rf "$TEMP_BACKUP"
            
            echo -e "${GREEN}✅ 更新完成，用户数据已恢复${NC}"
            ;;
    esac
    
    echo ""
    echo "按回车返回..."
    read
}

# 查看日志
view_logs() {
    echo ""
    echo -e "${CYAN}╔═══════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║             📋 日志查看                            ║${NC}"
    echo -e "${CYAN}╠═══════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║  [1] 实时日志监控                                 ║${NC}"
    echo -e "${CYAN}║  [2] 查看最新50行                                 ║${NC}"
    echo -e "${CYAN}║  [3] 查看错误日志                                 ║${NC}"
    echo -e "${CYAN}║  [4] 清空日志文件                                 ║${NC}"
    echo -e "${CYAN}║  [0] 返回主菜单                                   ║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════╝${NC}"
    echo -ne "请选择 [0-4]: "
    
    read choice
    
    case $choice in
        1)
            echo -e "${GREEN}实时日志 (按 Ctrl+C 退出)${NC}"
            tail -f "$LOG_FILE"
            ;;
        2)
            echo -e "${CYAN}最新50行日志:${NC}"
            tail -n 50 "$LOG_FILE"
            ;;
        3)
            echo -e "${RED}错误日志:${NC}"
            grep -i error "$LOG_FILE" | tail -n 30 || echo "无错误信息"
            ;;
        4)
            > "$LOG_FILE"
            echo -e "${GREEN}✅ 日志已清空${NC}"
            ;;
        0)
            return
            ;;
    esac
    
    echo ""
    echo "按回车返回..."
    read
}

# 备份用户数据
backup_user_data() {
    echo ""
    echo -e "${YELLOW}备份用户数据...${NC}"
    
    if [ ! -d "$ST_DIR" ]; then
        echo -e "${RED}错误: SillyTavern未安装${NC}"
        echo "按回车返回..."
        read
        return
    fi
    
    BACKUP_NAME="backup_$(date +%Y%m%d_%H%M%S)"
    BACKUP_PATH="$BACKUP_DIR/$BACKUP_NAME"
    mkdir -p "$BACKUP_PATH"
    
    cd "$ST_DIR"
    
    # 备份各种数据
    [ -d "data" ] && cp -r data "$BACKUP_PATH/" && echo "  ✅ 聊天数据"
    [ -d "public/characters" ] && cp -r public/characters "$BACKUP_PATH/" && echo "  ✅ 角色卡"
    [ -d "public/User Avatars" ] && cp -r "public/User Avatars" "$BACKUP_PATH/" && echo "  ✅ 用户头像"
    [ -d "public/worlds" ] && cp -r public/worlds "$BACKUP_PATH/" && echo "  ✅ 世界设定"
    [ -f "config.yaml" ] && cp config.yaml "$BACKUP_PATH/" && echo "  ✅ 配置文件"
    
    # 压缩备份
    cd "$BACKUP_DIR"
    tar -czf "${BACKUP_NAME}.tar.gz" "$BACKUP_NAME"
    rm -rf "$BACKUP_NAME"
    
    echo ""
    echo -e "${GREEN}✅ 备份完成: ${BACKUP_NAME}.tar.gz${NC}"
    echo ""
    echo "按回车返回..."
    read
}

# 恢复用户数据
restore_user_data() {
    echo ""
    echo -e "${CYAN}可用备份列表:${NC}"
    echo ""
    
    if [ ! -d "$BACKUP_DIR" ] || [ -z "$(ls -A "$BACKUP_DIR" 2>/dev/null)" ]; then
        echo -e "${YELLOW}没有找到备份文件${NC}"
        echo ""
        echo "按回车返回..."
        read
        return
    fi
    
    ls -lah "$BACKUP_DIR"/*.tar.gz 2>/dev/null | tail -5
    
    echo ""
    echo "输入备份文件名 (如: backup_20240101_120000.tar.gz):"
    read backup_file
    
    if [ -f "$BACKUP_DIR/$backup_file" ]; then
        echo -e "${YELLOW}正在恢复数据...${NC}"
        
        cd "$BACKUP_DIR"
        tar -xzf "$backup_file"
        BACKUP_NAME="${backup_file%.tar.gz}"
        
        cd "$ST_DIR"
        [ -d "$BACKUP_DIR/$BACKUP_NAME/data" ] && cp -r "$BACKUP_DIR/$BACKUP_NAME/data" ./ && echo "  ✅ 聊天数据"
        [ -d "$BACKUP_DIR/$BACKUP_NAME/characters" ] && cp -r "$BACKUP_DIR/$BACKUP_NAME/characters" public/ && echo "  ✅ 角色卡"
        [ -d "$BACKUP_DIR/$BACKUP_NAME/User Avatars" ] && cp -r "$BACKUP_DIR/$BACKUP_NAME/User Avatars" public/ && echo "  ✅ 用户头像"
        [ -d "$BACKUP_DIR/$BACKUP_NAME/worlds" ] && cp -r "$BACKUP_DIR/$BACKUP_NAME/worlds" public/ && echo "  ✅ 世界设定"
        [ -f "$BACKUP_DIR/$BACKUP_NAME/config.yaml" ] && cp "$BACKUP_DIR/$BACKUP_NAME/config.yaml" ./ && echo "  ✅ 配置文件"
        
        rm -rf "$BACKUP_DIR/$BACKUP_NAME"
        
        echo ""
        echo -e "${GREEN}✅ 数据恢复完成${NC}"
    else
        echo -e "${RED}备份文件不存在${NC}"
    fi
    
    echo ""
    echo "按回车返回..."
    read
}


# 一键全面更新
full_system_update() {
    echo ""
    echo -e "${YELLOW}🔧 一键全面更新${NC}"
    echo -e "${GRAY}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${CYAN}即将更新以下组件：${NC}"
    echo "  • Termux 系统包"
    echo "  • Node.js 和 NPM"
    echo "  • Git"
    echo "  • SillyTavern"
    echo "  • 管理器脚本"
    echo ""
    echo -e "${YELLOW}是否继续？(y/n): ${NC}"
    read -r confirm
    
    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        echo -e "${GRAY}已取消更新${NC}"
        echo "按回车返回..."
        read
        return
    fi
    
    echo ""
    
    # 1. 更新Termux系统
    echo -e "${CYAN}[1/5] 更新Termux系统包...${NC}"
    pkg update -y 2>/dev/null && pkg upgrade -y 2>/dev/null
    echo -e "${GREEN}  ✅ Termux更新完成${NC}"
    
    # 2. 更新Node.js和NPM
    echo ""
    echo -e "${CYAN}[2/5] 更新Node.js和NPM...${NC}"
    OLD_NODE=$(node -v 2>/dev/null || echo "未安装")
    OLD_NPM=$(npm -v 2>/dev/null || echo "未安装")
    
    pkg install nodejs -y 2>/dev/null
    npm install -g npm@latest 2>/dev/null
    
    NEW_NODE=$(node -v 2>/dev/null || echo "未安装")
    NEW_NPM=$(npm -v 2>/dev/null || echo "未安装")
    
    echo -e "${GREEN}  ✅ Node.js: $OLD_NODE → $NEW_NODE${NC}"
    echo -e "${GREEN}  ✅ NPM: $OLD_NPM → $NEW_NPM${NC}"
    
    # 3. 更新Git
    echo ""
    echo -e "${CYAN}[3/5] 更新Git...${NC}"
    OLD_GIT=$(git --version 2>/dev/null | awk '{print $3}' || echo "未安装")
    
    pkg install git -y 2>/dev/null
    
    NEW_GIT=$(git --version 2>/dev/null | awk '{print $3}' || echo "未安装")
    echo -e "${GREEN}  ✅ Git: $OLD_GIT → $NEW_GIT${NC}"
    
    # 4. 更新SillyTavern
    echo ""
    echo -e "${CYAN}[4/5] 更新SillyTavern...${NC}"
    if [ -d "$ST_DIR" ]; then
        cd "$ST_DIR"
        git pull 2>/dev/null
        npm install --production --no-audit --no-fund 2>/dev/null
        echo -e "${GREEN}  ✅ SillyTavern更新完成${NC}"
    else
        echo -e "${YELLOW}  ⚠️  SillyTavern未安装${NC}"
    fi
    
    # 5. 更新管理器脚本
    echo ""
    echo -e "${CYAN}[5/5] 检查管理器更新...${NC}"
    MANAGER_URL="https://raw.githubusercontent.com/ndganx/sillytavern-termux-installer/main/manager.sh"
    TEMP_MANAGER="/tmp/manager_new.sh"
    
    if curl -sL "$MANAGER_URL" -o "$TEMP_MANAGER" 2>/dev/null; then
        if [ -f "$TEMP_MANAGER" ]; then
            NEW_VERSION=$(grep "管理系统 v" "$TEMP_MANAGER" | head -1 | grep -oE "v[0-9.]+")
            CURRENT_VERSION=$(grep "管理系统 v" "$0" | head -1 | grep -oE "v[0-9.]+")
            
            if [ "$NEW_VERSION" != "$CURRENT_VERSION" ]; then
                cp "$TEMP_MANAGER" "$0"
                chmod +x "$0"
                echo -e "${GREEN}  ✅ 管理器已更新: $CURRENT_VERSION → $NEW_VERSION${NC}"
                echo -e "${YELLOW}  ⚠️  请重启管理器以使用新版本${NC}"
            else
                echo -e "${GREEN}  ✅ 管理器已是最新版本${NC}"
            fi
        fi
        rm -f "$TEMP_MANAGER"
    else
        echo -e "${YELLOW}  ⚠️  无法检查管理器更新${NC}"
    fi
    
    # 清理缓存
    echo ""
    echo -e "${CYAN}清理缓存...${NC}"
    npm cache clean --force 2>/dev/null
    pkg autoclean 2>/dev/null
    echo -e "${GREEN}  ✅ 缓存清理完成${NC}"
    
    echo ""
    echo -e "${GRAY}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}✨ 全面更新完成！${NC}"
    echo ""
    echo "按回车返回..."
    read
}

# 系统信息
system_info() {
    echo ""
    echo -e "${CYAN}╔═══════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                ℹ️  系统信息                         ║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════╝${NC}"
    echo ""
    
    echo -e "${YELLOW}SillyTavern 信息:${NC}"
    get_versions
    echo "  版本: $CURRENT_VERSION"
    echo "  路径: $ST_DIR"
    check_status
    echo "  状态: $STATUS"
    
    echo ""
    echo -e "${YELLOW}系统信息:${NC}"
    echo "  Node.js: $(node -v 2>/dev/null || echo '未安装')"
    echo "  NPM: $(npm -v 2>/dev/null || echo '未安装')"
    echo "  Git: $(git --version 2>/dev/null | awk '{print $3}' || echo '未安装')"
    
    echo ""
    echo -e "${YELLOW}内存信息:${NC}"
    free -h | grep -E "^Mem:|^Swap:"
    
    echo ""
    echo -e "${YELLOW}存储信息:${NC}"
    df -h "$HOME" | tail -1
    
    if [ -d "$ST_DIR" ]; then
        echo ""
        echo -e "${YELLOW}SillyTavern占用:${NC}"
        du -sh "$ST_DIR" 2>/dev/null
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
        4) update_st ;;
        5) view_logs ;;
        6) backup_user_data ;;
        7) restore_user_data ;;
        8) full_system_update ;;
        9) system_info ;;
        0) 
            echo ""
            echo -e "${GREEN}👋 感谢使用 SillyTavern 管理系统${NC}"
            exit 0 
            ;;
        *)
            # 无效输入
            ;;
    esac
done