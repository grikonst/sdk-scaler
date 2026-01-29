#!/bin/bash

# Определение размеров окон для TUI
TUI_HEIGHT=35
TUI_WIDTH=85
MENU_HEIGHT=25
PROGRESS_HEIGHT=15
INPUT_HEIGHT=16
MSG_HEIGHT=30

# Флаг прерывания пользователем
USER_INTERRUPTED=0

# Определяем TUI команду
TUI_CMD=""
if command -v dialog &> /dev/null; then
    TUI_CMD="dialog"
elif command -v whiptail &> /dev/null; then
    TUI_CMD="whiptail"
fi

# Colors for output (для консольного режима)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Configuration file
CONFIG_FILE="$HOME/.remote-sdk-manager.conf"

# Функция обработки прерывания
handle_interrupt() {
    USER_INTERRUPTED=1
    if [[ -z "$TUI_CMD" ]]; then
        echo -e "\n${YELLOW}⚠️  Прервано пользователем${NC}"
    else
        # Закрываем TUI диалоги если они открыты
        clear
    fi
}

# Функция проверки прерывания
check_interrupted() {
    if [[ $USER_INTERRUPTED -eq 1 ]]; then
        return 1
    fi
    return 0
}

# TUI Functions
show_message() {
    local title="$1"
    local message="$2"
    local height="${3:-$MSG_HEIGHT}"
    local width="${4:-$TUI_WIDTH}"
    
    if [[ -z "$TUI_CMD" ]]; then
        # Консольный режим
        echo ""
        echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
        echo -e "${BOLD} $title${NC}"
        echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
        echo -e "$message"
        echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
        echo ""
        return
    fi
    
    # TUI режим
    if [[ "$TUI_CMD" == "dialog" ]]; then
        dialog --title "$title" --msgbox "$message" "$height" "$width" 2>/dev/null
    elif [[ "$TUI_CMD" == "whiptail" ]]; then
        whiptail --title "$title" --msgbox "$message" "$height" "$width" 2>/dev/null
    fi
}

show_menu() {
    local title="$1"
    local prompt="$2"
    shift 2
    local options=("$@")
    
    if [[ -z "$TUI_CMD" ]]; then
        # Консольный режим
        echo ""
        echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
        echo -e "${BOLD} $title${NC}"
        echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
        echo -e "$prompt"
        echo -e "${CYAN}────────────────────────────────────────────────────────────${NC}"
        
        local index=1
        for ((i=0; i<${#options[@]}; i+=2)); do
            echo -e " ${YELLOW}$index${NC}) ${options[i+1]}"
            ((index++))
        done
        echo -e " ${YELLOW}0${NC}) 🔙 Назад"
        echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
        echo -n -e " 📍 Выберите пункт (Ctrl+C для выхода): "
        read -r choice
        
        # Проверяем Ctrl+C
        if check_interrupted; then
            # Преобразуем числовой выбор в значение
            local selected_index=$(( (choice * 2) - 2 ))
            if [[ $selected_index -ge 0 ]] && [[ $selected_index -lt ${#options[@]} ]]; then
                echo "${options[$selected_index]}"
            else
                echo ""
            fi
        else
            echo ""
        fi
        return
    fi
    
    # TUI режим
    local choice
    if [[ "$TUI_CMD" == "dialog" ]]; then
        choice=$(dialog --title "$title" --menu "$prompt" $TUI_HEIGHT $TUI_WIDTH $MENU_HEIGHT "${options[@]}" 3>&1 1>&2 2>&3)
    elif [[ "$TUI_CMD" == "whiptail" ]]; then
        local whiptail_options=()
        for ((i=0; i<${#options[@]}; i+=2)); do
            whiptail_options+=("${options[i]}" "${options[i+1]}")
        done
        choice=$(whiptail --title "$title" --menu "$prompt" $TUI_HEIGHT $TUI_WIDTH $MENU_HEIGHT "${whiptail_options[@]}" 3>&1 1>&2 2>&3)
    fi
    
    # Если пользователь нажал ESC или Ctrl+C в TUI
    if [[ $? -eq 1 ]] || [[ $? -eq 255 ]] || ! check_interrupted; then
        echo ""
    else
        echo "$choice"
    fi
}

show_input() {
    local title="$1"
    local prompt="$2"
    local default="$3"
    
    if [[ -z "$TUI_CMD" ]]; then
        # Консольный режим
        echo ""
        echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
        echo -e "${BOLD} $title${NC}"
        echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
        echo -e "$prompt"
        echo -n -e " [${GREEN}$default${NC}] (Enter для принятия, Ctrl+C для отмены): "
        read -r input
        
        if check_interrupted; then
            echo "${input:-$default}"
        else
            echo "$default"
        fi
        return
    fi
    
    # TUI режим
    local input
    if [[ "$TUI_CMD" == "dialog" ]]; then
        input=$(dialog --title "$title" --inputbox "$prompt" $INPUT_HEIGHT $TUI_WIDTH "$default" 3>&1 1>&2 2>&3)
    elif [[ "$TUI_CMD" == "whiptail" ]]; then
        input=$(whiptail --title "$title" --inputbox "$prompt" $INPUT_HEIGHT $TUI_WIDTH "$default" 3>&1 1>&2 2>&3)
    fi
    
    if [[ $? -eq 1 ]] || [[ $? -eq 255 ]] || ! check_interrupted; then
        echo "$default"
    else
        echo "$input"
    fi
}

show_yesno() {
    local title="$1"
    local message="$2"
    
    if [[ -z "$TUI_CMD" ]]; then
        # Консольный режим
        echo ""
        echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
        echo -e "${BOLD} $title${NC}"
        echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
        echo -e "$message"
        echo -n -e " ${CYAN}(y/N, Ctrl+C для отмены)${NC}: "
        read -r response
        
        if check_interrupted; then
            [[ "$response" =~ ^[Yy]$ ]] && return 0 || return 1
        else
            return 1
        fi
    fi
    
    # TUI режим
    if [[ "$TUI_CMD" == "dialog" ]]; then
        dialog --title "$title" --yesno "$message" $INPUT_HEIGHT $TUI_WIDTH 3>&1 1>&2 2>&3
        local result=$?
    elif [[ "$TUI_CMD" == "whiptail" ]]; then
        whiptail --title "$title" --yesno "$message" $INPUT_HEIGHT $TUI_WIDTH 3>&1 1>&2 2>&3
        local result=$?
    fi
    
    if [[ $result -eq 1 ]] || [[ $result -eq 255 ]] || ! check_interrupted; then
        return 1
    fi
    return $result
}

show_progress() {
    local title="$1"
    local prompt="$2"
    local percent="$3"
    
    # Проверяем не прервал ли пользователь
    if ! check_interrupted; then
        return
    fi
    
    if [[ -z "$TUI_CMD" ]]; then
        # Консольный режим
        echo -e "📊 ${CYAN}$title${NC}: $prompt - ${GREEN}${percent}%${NC}"
        return
    fi
    
    # TUI режим
    if [[ "$TUI_CMD" == "dialog" ]]; then
        echo "$percent" | dialog --title "$title" --gauge "$prompt" $PROGRESS_HEIGHT $TUI_WIDTH 0 2>/dev/null
    elif [[ "$TUI_CMD" == "whiptail" ]]; then
        echo "$percent" | whiptail --title "$title" --gauge "$prompt" $PROGRESS_HEIGHT $TUI_WIDTH 0 2>/dev/null
    fi
}

# Функция для отображения ошибки
show_error() {
    local message="$1"
    show_message "ОШИБКА" "$message" "$MSG_HEIGHT" "$TUI_WIDTH"
}

# Функция для отображения успеха
show_success() {
    local message="$1"
    show_message "УСПЕХ" "$message" "$MSG_HEIGHT" "$TUI_WIDTH"
}

# Функция для отображения информации
show_info() {
    local message="$1"
    show_message "ИНФОРМАЦИЯ" "$message" "$MSG_HEIGHT" "$TUI_WIDTH"
}

# Default configuration
load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
    else
        # Set defaults
        CONFIGURATOR_HOST="127.0.0.1"
        CONFIGURATOR_PORT="5070"
        BASE_PORT="5220"
        INSTANCE_COUNT="2"
        WORKER_COUNT="1"
        RELOAD_CONFIG="1"
        RELOAD_CONFIG_INTERVAL="10"
        LOG_DIR="/tmp/logs/remote-sdk"
        NGINX_CONF_PATH="$PWD/nginx.conf"
        NGINX_IMAGE="dockerhub.visionlabs.ru/luna/nginx:1.17.4-alpine"
        REMOTE_SDK_IMAGE="dockerhub.visionlabs.ru/luna/luna-remote-sdk:v.0.28.0"
        USE_GPU="0"  # 0 = CPU, 1 = GPU
        GPU_DEVICE="0"  # GPU device number
        # Save defaults
        save_config
    fi
}

# Save configuration
save_config() {
    cat > "$CONFIG_FILE" << EOF
CONFIGURATOR_HOST="$CONFIGURATOR_HOST"
CONFIGURATOR_PORT="$CONFIGURATOR_PORT"
BASE_PORT="$BASE_PORT"
INSTANCE_COUNT="$INSTANCE_COUNT"
WORKER_COUNT="$WORKER_COUNT"
RELOAD_CONFIG="$RELOAD_CONFIG"
RELOAD_CONFIG_INTERVAL="$RELOAD_CONFIG_INTERVAL"
LOG_DIR="$LOG_DIR"
NGINX_CONF_PATH="$NGINX_CONF_PATH"
NGINX_IMAGE="$NGINX_IMAGE"
REMOTE_SDK_IMAGE="$REMOTE_SDK_IMAGE"
USE_GPU="$USE_GPU"
GPU_DEVICE="$GPU_DEVICE"
EOF
}

# Load configuration
load_config

# Function to check if port is available
check_port() {
    if command -v ss &> /dev/null && ss -tuln | grep -q ":$1 "; then
        return 1
    elif command -v netstat &> /dev/null && netstat -tuln | grep -q ":$1 "; then
        return 1
    elif grep -q ":$1 " /proc/net/tcp 2>/dev/null; then
        return 1
    fi
    return 0
}

# Function to check if GPU is available
check_gpu_availability() {
    if command -v nvidia-smi &> /dev/null && docker info 2>/dev/null | grep -q "Runtimes.*nvidia"; then
        return 0
    else
        return 1
    fi
}

# Function to get GPU status
get_gpu_status() {
    if check_gpu_availability; then
        GPU_NAME=$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -1)
        if [[ -z "$TUI_CMD" ]]; then
            echo -e "${GREEN}Доступна${NC}${GPU_NAME:+ ($GPU_NAME)}"
        else
            echo "Доступна${GPU_NAME:+ ($GPU_NAME)}"
        fi
    else
        if [[ -z "$TUI_CMD" ]]; then
            echo -e "${YELLOW}Не доступна${NC}"
        else
            echo "Не доступна"
        fi
    fi
}

# Function to perform health check on remote-sdk instance
check_remote_sdk_health() {
    local port="$1"
    local timeout=10
    
    if command -v curl &> /dev/null && curl -L --fail --silent --max-time $timeout "127.0.0.1:$port/healthcheck" > /dev/null; then
        return 0
    elif command -v wget &> /dev/null && wget --quiet --timeout=$timeout --tries=1 -O /dev/null "http://127.0.0.1:$port/healthcheck" 2>/dev/null; then
        return 0
    else
        check_port $port
        return $?
    fi
}

# Function to build docker run command for luna-remote-sdk
build_docker_run_command() {
    local instance_num="$1"
    local port="$2"
    local instance_log_dir="$3"
    
    local cmd="docker run"
    
    if [ "$USE_GPU" = "1" ] && check_gpu_availability; then
        cmd="$cmd --gpus device=${GPU_DEVICE}"
    fi
    
    cmd="$cmd --env=CONFIGURATOR_HOST=\"$CONFIGURATOR_HOST\""
    cmd="$cmd --env=CONFIGURATOR_PORT=\"$CONFIGURATOR_PORT\""
    cmd="$cmd --env=PORT=\"$port\""
    cmd="$cmd --env=WORKER_COUNT=\"$WORKER_COUNT\""
    cmd="$cmd --env=RELOAD_CONFIG=\"$RELOAD_CONFIG\""
    cmd="$cmd --env=RELOAD_CONFIG_INTERVAL=\"$RELOAD_CONFIG_INTERVAL\""
    cmd="$cmd -v /etc/localtime:/etc/localtime:ro"
    cmd="$cmd -v \"$instance_log_dir:/srv/logs\""
    cmd="$cmd --network=host"
    cmd="$cmd --name=\"luna-remote-sdk-$instance_num\""
    cmd="$cmd --restart=always"
    cmd="$cmd --detach=true"
    cmd="$cmd --health-cmd=\"curl -L --fail 127.0.0.1:$port/healthcheck\""
    cmd="$cmd --health-start-period=10s"
    cmd="$cmd --health-interval=5s"
    cmd="$cmd --health-timeout=10s"
    cmd="$cmd --health-retries=10"
    cmd="$cmd \"$REMOTE_SDK_IMAGE\""
    
    echo "$cmd"
}

# Function to stop all containers
stop_all_containers() {
    local stopped=0
    
    # Stop luna-remote-sdk containers
    local remote_sdk_containers=$(docker ps -a --filter "name=luna-remote-sdk" --format "{{.Names}}" 2>/dev/null)
    for container in $remote_sdk_containers; do
        docker stop "$container" > /dev/null 2>&1
        docker rm "$container" > /dev/null 2>&1
        ((stopped++))
    done
    
    # Stop old remote-sdk containers
    local old_containers=$(docker ps -a --filter "name=remote-sdk" --format "{{.Names}}" 2>/dev/null)
    for container in $old_containers; do
        docker stop "$container" > /dev/null 2>&1
        docker rm "$container" > /dev/null 2>&1
        ((stopped++))
    done
    
    # Stop nginx
    if docker ps -a --filter "name=nginx" 2>/dev/null | grep -q "nginx"; then
        docker stop nginx > /dev/null 2>&1
        docker rm nginx > /dev/null 2>&1
        ((stopped++))
    fi
    
    # Clean up log directories
    if [ -d "$LOG_DIR" ]; then
        rm -rf "$LOG_DIR"/instance-* 2>/dev/null
    fi
    
    if [ $stopped -eq 0 ]; then
        show_info "Нет запущенных контейнеров"
    else
        show_success "Остановлено контейнеров: $stopped"
    fi
}

# Function to generate nginx configuration
generate_nginx_config() {
    show_info "Генерация конфигурации nginx..."
    
    mkdir -p "$(dirname "$NGINX_CONF_PATH")"
    
    cat > "$NGINX_CONF_PATH" << 'EOF'
user nginx;
worker_processes auto;
pid /run/nginx.pid;
events {
    worker_connections 1024;
}

http {
    log_format main '$remote_addr [$time_local] "$request" {$request_time} '
                    '$status $body_bytes_sent {$upstream_cache_status} '
                    '{$upstream_addr} {$upstream_response_time} {$upstream_status}';
                    
    access_log /var/log/nginx/access.log main;
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;
    client_max_body_size 32m;
    client_body_buffer_size 32k;
    
    include /etc/nginx/mime.types;
    default_type application/octet-stream;
    
    upstream luna-remote-sdk {
EOF
    
    for i in $(seq 1 $INSTANCE_COUNT); do
        PORT=$((BASE_PORT + i))
        echo "        server 127.0.0.1:$PORT fail_timeout=0;" >> "$NGINX_CONF_PATH"
    done
    
    cat >> "$NGINX_CONF_PATH" << EOF
    }

    server {
        listen $BASE_PORT;
        client_max_body_size 4G;
        server_name 127.0.0.1;

        location / {
            proxy_set_header Host \$http_host;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_redirect off;
            proxy_buffering off;
            proxy_pass http://luna-remote-sdk;
        }
    }
}
EOF
    
    if [ $? -eq 0 ]; then
        local config_info="Конфигурация сгенерирована: $NGINX_CONF_PATH\n\n"
        config_info+="Балансировка порт: $BASE_PORT\n"
        config_info+="Инстансы:\n"
        for i in $(seq 1 $INSTANCE_COUNT); do
            PORT=$((BASE_PORT + i))
            config_info+="  $i → 127.0.0.1:$PORT\n"
        done
        show_success "$config_info"
        return 0
    else
        show_error "Ошибка генерации конфигурации"
        return 1
    fi
}

# Function to start luna-remote-sdk instances
start_remote_sdk_instances() {
    show_info "Запуск инстансов luna-remote-sdk..."
    
    if ! check_interrupted; then
        return 1
    fi
    
    if ! docker info > /dev/null 2>&1; then
        show_error "Docker не запущен"
        return 1
    fi
    
    if [ "$USE_GPU" = "1" ] && ! check_gpu_availability; then
        show_error "GPU режим включен, но GPU не доступна. Переключаем в CPU режим."
        USE_GPU="0"
        save_config
    fi
    
    mkdir -p "$LOG_DIR"
    
    local started=0
    local failed=0
    local total=$INSTANCE_COUNT
    
    for i in $(seq 1 $INSTANCE_COUNT); do
        # Проверяем не прервал ли пользователь
        if ! check_interrupted; then
            show_info "Запуск прерван пользователем"
            return 1
        fi
        
        PORT=$((BASE_PORT + i))
        INSTANCE_LOG_DIR="$LOG_DIR/instance-$i"
        mkdir -p "$INSTANCE_LOG_DIR"
        
        if ! check_port $PORT; then
            show_error "Порт $PORT занят для инстанса $i"
            ((failed++))
            continue
        fi
        
        docker rm -f luna-remote-sdk-$i > /dev/null 2>&1
        
        DOCKER_CMD=$(build_docker_run_command "$i" "$PORT" "$INSTANCE_LOG_DIR")
        
        if eval "$DOCKER_CMD" > /dev/null 2>&1; then
            ((started++))
        else
            show_error "Ошибка запуска инстанса $i"
            ((failed++))
        fi
        
        # Показываем прогресс
        local percent=$(( (i * 100) / total ))
        show_progress "Запуск инстансов" "Запуск инстанса $i/$total" "$percent"
        
        sleep 0.5
    done
    
    if [ $started -gt 0 ]; then
        show_success "Запущено инстансов: $started"
        sleep 10
        check_instances_health
    fi
    
    if [ $failed -gt 0 ]; then
        show_error "Не запущено инстансов: $failed"
    fi
    
    return $((failed > 0 ? 1 : 0))
}

# Function to check health of all instances
check_instances_health() {
    local healthy=0
    local unhealthy=0
    local starting=0
    local status_info=""
    
    for i in $(seq 1 $INSTANCE_COUNT); do
        PORT=$((BASE_PORT + i))
        
        if docker ps --filter "name=luna-remote-sdk-$i" --format "{{.Names}}" 2>/dev/null | grep -q "luna-remote-sdk-$i"; then
            HEALTH_STATUS=$(docker inspect --format='{{.State.Health.Status}}' "luna-remote-sdk-$i" 2>/dev/null || echo "unknown")
            
            case $HEALTH_STATUS in
                "healthy")
                    status_info+="✓ luna-remote-sdk-$i (порт: $PORT): HEALTHY\n"
                    ((healthy++))
                    ;;
                "unhealthy")
                    status_info+="✗ luna-remote-sdk-$i (порт: $PORT): UNHEALTHY\n"
                    ((unhealthy++))
                    ;;
                "starting")
                    status_info+="● luna-remote-sdk-$i (порт: $PORT): ЗАПУСКАЕТСЯ\n"
                    ((starting++))
                    ;;
                *)
                    if check_remote_sdk_health $PORT; then
                        status_info+="✓ luna-remote-sdk-$i (порт: $PORT): HEALTHY (прямая проверка)\n"
                        ((healthy++))
                    else
                        status_info+="● luna-remote-sdk-$i (порт: $PORT): ПРОВЕРКА\n"
                        ((starting++))
                    fi
                    ;;
            esac
        else
            status_info+="✗ luna-remote-sdk-$i (порт: $PORT): НЕ ЗАПУЩЕН\n"
            ((unhealthy++))
        fi
    done
    
    status_info+="\n════════════════════════════════════════════════════════════\n"
    status_info+="Статус:\n"
    status_info+="  запущен: $healthy\n"
    status_info+="  старт: $starting\n"
    status_info+="  ошибка: $unhealthy\n"
    
    if [ $unhealthy -eq 0 ] && [ $starting -eq 0 ]; then
        status_info+="\n✅ Все инстансы готовы"
        show_success "$status_info"
        return 0
    elif [ $unhealthy -gt 0 ]; then
        status_info+="\n⚠️ Требуют внимания"
        show_error "$status_info"
        return 1
    else
        status_info+="\n⏳ Инстансы запускаются"
        show_info "$status_info"
        return 2
    fi
}

# Function to start nginx
start_nginx() {
    show_info "Запуск балансировщика nginx..."
    
    if ! check_interrupted; then
        return 1
    fi
    
    if ! docker info > /dev/null 2>&1; then
        show_error "Docker не запущен"
        return 1
    fi
    
    if [ ! -f "$NGINX_CONF_PATH" ]; then
        if ! generate_nginx_config; then
            show_error "Не удалось создать конфигурацию"
            return 1
        fi
    fi
    
    if ! check_port $BASE_PORT; then
        show_error "Порт $BASE_PORT занят"
        return 1
    fi
    
    if docker ps -a --filter "name=nginx" 2>/dev/null | grep -q "nginx"; then
        docker stop nginx > /dev/null 2>&1
        docker rm nginx > /dev/null 2>&1
    fi
    
    if [ ! -r "$NGINX_CONF_PATH" ]; then
        show_error "Файл конфигурации недоступен: $NGINX_CONF_PATH"
        return 1
    fi
    
    show_progress "Запуск nginx" "Подготовка контейнера..." "25"
    
    if ! check_interrupted; then
        return 1
    fi
    
    if docker run \
        -v /etc/localtime:/etc/localtime:ro \
        -v "$NGINX_CONF_PATH:/etc/nginx/nginx.conf" \
        --name=nginx \
        --restart=always \
        --detach=true \
        --network=host \
        "$NGINX_IMAGE" > /dev/null 2>&1; then
        
        sleep 2
        
        show_progress "Запуск nginx" "Проверка состояния..." "75"
        
        if docker ps --filter "name=nginx" 2>/dev/null | grep -q "nginx"; then
            show_progress "Запуск nginx" "Готово!" "100"
            show_success "nginx запущен на порту $BASE_PORT"
            return 0
        else
            show_error "nginx запустился, но остановился"
            docker logs nginx --tail 20 2>/dev/null || true
            return 1
        fi
    else
        show_error "Ошибка запуска nginx"
        return 1
    fi
}

# Function to show status
show_status() {
    local status_info=""
    
    status_info+="LUNA-REMOTE-SDK ИНСТАНСЫ:\n\n"
    status_info+="GPU режим: $([ "$USE_GPU" = "1" ] && echo "Включен" || echo "Выключен")\n"
    status_info+="GPU доступность: $(get_gpu_status)\n\n"
    
    local running_instances=0
    local healthy_instances=0
    
    for i in $(seq 1 $INSTANCE_COUNT); do
        PORT=$((BASE_PORT + i))
        INSTANCE_LOG_DIR="$LOG_DIR/instance-$i"
        
        if docker ps --filter "name=luna-remote-sdk-$i" --format "{{.Names}}" 2>/dev/null | grep -q "luna-remote-sdk-$i"; then
            CONTAINER_ID=$(docker ps --filter "name=luna-remote-sdk-$i" --format "{{.ID}}" 2>/dev/null)
            UPTIME=$(docker ps --filter "name=luna-remote-sdk-$i" --format "{{.RunningFor}}" 2>/dev/null)
            HEALTH_STATUS=$(docker inspect --format='{{.State.Health.Status}}' "luna-remote-sdk-$i" 2>/dev/null || echo "unknown")
            
            case $HEALTH_STATUS in
                "healthy")
                    HEALTH_ICON="✓"
                    HEALTH_TEXT="HEALTHY"
                    ((healthy_instances++))
                    ;;
                "unhealthy")
                    HEALTH_ICON="✗"
                    HEALTH_TEXT="UNHEALTHY"
                    ;;
                "starting")
                    HEALTH_ICON="●"
                    HEALTH_TEXT="STARTING"
                    ;;
                *)
                    HEALTH_ICON="?"
                    HEALTH_TEXT="unknown"
                    ;;
            esac
            
            status_info+="  $HEALTH_ICON luna-remote-sdk-$i (порт: $PORT)\n"
            status_info+="     ID: ${CONTAINER_ID:0:12} | Uptime: $UPTIME\n"
            status_info+="     Status: $HEALTH_TEXT\n"
            
        else
            status_info+="  ✗ luna-remote-sdk-$i (порт: $PORT) - ОСТАНОВЛЕН\n"
        fi
        status_info+="\n"
    done
    
    status_info+="NGINX БАЛАНСИРОВЩИК:\n\n"
    
    if docker ps --filter "name=nginx" --format "{{.Names}}" 2>/dev/null | grep -q "nginx"; then
        CONTAINER_ID=$(docker ps --filter "name=nginx" --format "{{.ID}}" 2>/dev/null)
        UPTIME=$(docker ps --filter "name=nginx" --format "{{.RunningFor}}" 2>/dev/null)
        status_info+="  ✓ nginx запущен\n"
        status_info+="     Port: $BASE_PORT | ID: ${CONTAINER_ID:0:12}\n"
        status_info+="     Uptime: $UPTIME | Instances: $INSTANCE_COUNT\n"
    else
        status_info+="  ✗ nginx: ОСТАНОВЛЕН\n"
    fi
    
    status_info+="\n════════════════════════════════════════════════════════════\n"
    status_info+="СТАТУС:\n"
    status_info+="  Mode: $([ "$USE_GPU" = "1" ] && echo "GPU" || echo "CPU")\n"
    status_info+="  Load Balancer: $(docker ps --filter "name=nginx" 2>/dev/null | grep -q "nginx" && echo "АКТИВЕН" || echo "НЕАКТИВЕН")\n"
    
    show_message "СТАТУС СИСТЕМЫ" "$status_info"
}

# Function to configure settings
configure_settings() {
    while check_interrupted; do
        local settings_info="Текущие настройки:\n\n"
        settings_info+="1. Хост конфигуратора: $CONFIGURATOR_HOST\n"
        settings_info+="2. Порт конфигуратора: $CONFIGURATOR_PORT\n"
        settings_info+="3. Базовый порт: $BASE_PORT\n"
        settings_info+="4. Инстансы: $INSTANCE_COUNT\n"
        settings_info+="5. Воркеры: $WORKER_COUNT\n"
        settings_info+="6. Перезагрузка конфига: $([ "$RELOAD_CONFIG" = "1" ] && echo "Да" || echo "Нет")\n"
        settings_info+="7. Интервал перезагрузки: $RELOAD_CONFIG_INTERVAL сек.\n"
        settings_info+="8. Директория логов: $LOG_DIR\n"
        settings_info+="9. Путь к конфигу nginx: $NGINX_CONF_PATH\n"
        settings_info+="10. GPU режим: $([ "$USE_GPU" = "1" ] && echo "Включен" || echo "Выключен")\n"
        settings_info+="11. GPU устройство: $GPU_DEVICE\n\n"
        settings_info+="Статус GPU: $(get_gpu_status)\n"
        
        local choice=$(show_menu "КОНФИГУРАЦИЯ" "$settings_info" \
            "1" "Хост конфигуратора" \
            "2" "Порт конфигуратора" \
            "3" "Базовый порт" \
            "4" "Количество инстансов" \
            "5" "Количество воркеров" \
            "6" "Перезагрузка конфига" \
            "7" "Интервал перезагрузки" \
            "8" "Директория логов" \
            "9" "Путь к конфигу nginx" \
            "10" "GPU режим" \
            "11" "GPU устройство" \
            "0" "Назад")
        
        case $choice in
            1) 
                local input=$(show_input "Хост конфигуратора" "Введите хост конфигуратора:" "$CONFIGURATOR_HOST")
                [ -n "$input" ] && CONFIGURATOR_HOST="$input"
                ;;
            2) 
                local input=$(show_input "Порт конфигуратора" "Введите порт конфигуратора:" "$CONFIGURATOR_PORT")
                [ -n "$input" ] && CONFIGURATOR_PORT="$input"
                ;;
            3) 
                local input=$(show_input "Базовый порт" "Введите базовый порт:" "$BASE_PORT")
                [ -n "$input" ] && BASE_PORT="$input"
                ;;
            4) 
                while true; do
                    local input=$(show_input "Количество инстансов" "Введите количество инстансов:" "$INSTANCE_COUNT")
                    [ -z "$input" ] && break
                    [[ "$input" =~ ^[0-9]+$ && "$input" -gt 0 ]] && INSTANCE_COUNT="$input" && break
                    show_error "Введите положительное число"
                done
                ;;
            5) 
                local input=$(show_input "Количество воркеров" "Введите количество воркеров:" "$WORKER_COUNT")
                [[ -n "$input" && "$input" =~ ^[0-9]+$ && "$input" -gt 0 ]] && WORKER_COUNT="$input"
                ;;
            6) 
                RELOAD_CONFIG=$([ "$RELOAD_CONFIG" = "1" ] && echo "0" || echo "1")
                ;;
            7) 
                local input=$(show_input "Интервал перезагрузки" "Введите интервал перезагрузки в секундах:" "$RELOAD_CONFIG_INTERVAL")
                [[ -n "$input" && "$input" =~ ^[0-9]+$ && "$input" -gt 0 ]] && RELOAD_CONFIG_INTERVAL="$input"
                ;;
            8) 
                local input=$(show_input "Директория логов" "Введите путь к директории логов:" "$LOG_DIR")
                [ -n "$input" ] && LOG_DIR="$input"
                ;;
            9) 
                local input=$(show_input "Путь к конфигу nginx" "Введите путь к конфигу nginx:" "$NGINX_CONF_PATH")
                [ -n "$input" ] && NGINX_CONF_PATH="$input"
                ;;
            10) 
                USE_GPU=$([ "$USE_GPU" = "1" ] && echo "0" || echo "1")
                if [ "$USE_GPU" = "1" ] && ! check_gpu_availability; then
                    show_error "GPU не доступна"
                    USE_GPU="0"
                fi
                ;;
            11) 
                local input=$(show_input "GPU устройство" "Введите номер GPU устройства:" "$GPU_DEVICE")
                [[ -n "$input" && "$input" =~ ^[0-9]+$ ]] && GPU_DEVICE="$input"
                ;;
            0) 
                save_config
                return 
                ;;
            *) 
                continue
                ;;
        esac
        
        save_config
    done
}

# Function to start all instances and nginx
start_all() {
    show_info "Запуск всех сервисов..."
    
    if ! check_interrupted; then
        return
    fi
    
    if [ "$USE_GPU" = "1" ] && ! check_gpu_availability; then
        show_error "GPU не доступна, переключаемся в CPU режим"
        USE_GPU="0"
        save_config
    fi
    
    stop_all_containers
    
    if start_remote_sdk_instances; then
        sleep 3
        
        if generate_nginx_config && start_nginx; then
            local success_msg="Все сервисы запущены\n\n"
            success_msg+="Балансировщик: http://127.0.0.1:$BASE_PORT\n"
            success_msg+="Режим: $([ "$USE_GPU" = "1" ] && echo "GPU" || echo "CPU")\n"
            success_msg+="Логи: $LOG_DIR"
            show_success "$success_msg"
        else
            show_error "Ошибка запуска nginx"
        fi
    else
        show_error "Ошибка запуска инстансов"
    fi
}

# Function to restart all services
restart_all() {
    show_info "Перезапуск всех сервисов..."
    
    if ! check_interrupted; then
        return
    fi
    
    stop_all_containers
    sleep 2
    start_all
}

# Function to display main menu
show_main_menu() {
    local gpu_status=$(get_gpu_status)
    local mode_status=$([ "$USE_GPU" = "1" ] && echo "GPU" || echo "CPU")
    
    local menu_info="Статус GPU: $gpu_status\n"
    menu_info+="Режим работы: $mode_status\n\n"
    
    local choice=$(show_menu "Luna-Remote-SDK Scaler" "$menu_info" \
        "1" "🚀 Запуск всех инстансов" \
        "2" "🛑 Остановка всех инстансов" \
        "3" "📊 Статус инстансов" \
        "4" "⚙️ Конфигурация" \
        "5" "🌐 Запуск nginx" \
        "6" "📝 Генерация конфига nginx" \
        "7" "🔄 Перезапуск всех сервисов" \
        "0" "🚪 Выход")
    
    echo "$choice"
}

# Main program loop
main() {
    # Устанавливаем обработчик прерываний
    trap 'handle_interrupt' INT
    
    load_config
    
    if ! command -v docker &> /dev/null; then
        show_error "Docker не установлен"
        exit 1
    fi
    
    if ! docker info > /dev/null 2>&1; then
        show_error "Docker демон не запущен"
        exit 1
    fi
    
    while check_interrupted; do
        choice=$(show_main_menu)
        
        case $choice in
            1) start_all ;;
            2) stop_all_containers ;;
            3) show_status ;;
            4) configure_settings ;;
            5) start_nginx ;;
            6) generate_nginx_config ;;
            7) restart_all ;;
            0) exit 0 ;;
            *) 
                # Если выбор пустой (пользователь нажал Ctrl+C), выходим
                if [[ -z "$choice" ]]; then
                    exit 0
                fi
                continue 
                ;;
        esac
    done
    
    # Если вышли из цикла из-за прерывания
    echo -e "\n${YELLOW}Программа завершена${NC}"
    exit 0
}

# Run main function
main
