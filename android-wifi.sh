#!/bin/bash
# =============================================================================
# Android.app - Conexión WiFi para scrcpy (autocontenida)
# =============================================================================

# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║                         CONFIGURACIÓN SCRCPY                              ║
# ╠═══════════════════════════════════════════════════════════════════════════╣
# ║  Modifica estas opciones según tus preferencias                           ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

# Bitrate del video (menor = menos lag por WiFi, peor calidad)
BITRATE="2M"

# Resolución máxima (menor = mejor rendimiento WiFi)
MAX_SIZE="800"

# Mantener teléfono despierto mientras scrcpy está conectado
# true = no se suspende (pantalla puede estar apagada pero no duerme)
# false = comportamiento normal del teléfono
STAY_AWAKE=true

# Brillo bajo en lugar de apagar pantalla (más seguro)
# Valor de 1-255 (10 = ~4% brillo)
LOW_BRIGHTNESS=10

# Tipo de teclado: uhid (mejor), sdk, aoa
KEYBOARD="uhid"

# Carpeta destino al arrastrar archivos a scrcpy
PUSH_TARGET="/sdcard/Pictures/Push"

# ═══════════════════════════════════════════════════════════════════════════

CONFIG_FILE="$HOME/.android_scrcpy_ip"
PORT="5555"

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

show_header() {
    clear
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}       📱 Conexión Android para scrcpy${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

check_adb() {
    if ! adb get-state 1>/dev/null 2>&1; then
        echo -e "${YELLOW}⚠️  ADB ya está corriendo o no responde${NC}"
        echo ""
        echo -e "  ${GREEN}[1]${NC} Matar ADB y reiniciar (recomendado)"
        echo -e "  ${BLUE}[2]${NC} Intentar usar ADB existente"
        echo ""
        echo -e "${YELLOW}Seleccioná (1/2):${NC}"
        read -n 1 choice
        echo ""
        
        case "$choice" in
            1)
                echo -e "${YELLOW}🔄 Matando ADB...${NC}"
                adb kill-server 2>/dev/null
                sleep 2
                adb start-server
                ;;
            2)
                echo -e "${BLUE}🔄 Usando ADB existente...${NC}"
                ;;
            *)
                echo -e "${YELLOW}🔄 Opción por defecto: matar ADB...${NC}"
                adb kill-server 2>/dev/null
                sleep 2
                adb start-server
                ;;
        esac
    fi
}

store_brightness() {
    ORIGINAL_BRIGHTNESS=$(adb shell settings get system screen_brightness 2>/dev/null | tr -d '\r')
    ORIGINAL_BRIGHTNESS_MODE=$(adb shell settings get system screen_brightness_mode 2>/dev/null | tr -d '\r')
    [ -z "$ORIGINAL_BRIGHTNESS" ] && ORIGINAL_BRIGHTNESS=128
    [ -z "$ORIGINAL_BRIGHTNESS_MODE" ] && ORIGINAL_BRIGHTNESS_MODE=1
}

set_low_brightness() {
    echo -e "${YELLOW}🔅 Aplicando brillo bajo...${NC}"
    adb shell settings put system screen_brightness_mode 0
    adb shell settings put system screen_brightness "$LOW_BRIGHTNESS"
    NEW_BRIGHTNESS=$(adb shell settings get system screen_brightness | tr -d '\r')
    echo -e "${YELLOW}🔅 Brillo: $NEW_BRIGHTNESS${NC}"
}

restore_brightness() {
    if [ -n "$ORIGINAL_BRIGHTNESS" ]; then
        adb shell settings put system screen_brightness "$ORIGINAL_BRIGHTNESS"
        echo -e "${YELLOW}🔅 Brillo restaurado: $ORIGINAL_BRIGHTNESS${NC}"
    fi
    if [ -n "$ORIGINAL_BRIGHTNESS_MODE" ]; then
        adb shell settings put system screen_brightness_mode "$ORIGINAL_BRIGHTNESS_MODE"
    fi
}

cleanup_on_exit() {
    restore_brightness
}

# Menú de selección de conexión con timeout
select_connection_mode() {
    show_header
    echo -e "${YELLOW}¿Cómo querés conectarte?${NC}"
    echo ""
    echo -e "  ${GREEN}[1]${NC} WiFi (por defecto)"
    echo -e "  ${BLUE}[2]${NC} USB"
    echo ""
    echo -e "${YELLOW}Seleccioná (1/2) o esperá 3 segundos para WiFi...${NC}"
    
    # Leer con timeout de 3 segundos
    read -t 3 -n 1 choice
    echo ""
    
    case "$choice" in
        2)
            CONNECTION_MODE="usb"
            echo -e "${BLUE}📲 Modo USB seleccionado${NC}"
            ;;
        *)
            CONNECTION_MODE="wifi"
            echo -e "${GREEN}📶 Modo WiFi seleccionado${NC}"
            ;;
    esac
    sleep 1
}

# Función para lanzar scrcpy por USB (sin WiFi)
launch_scrcpy_usb() {
    echo -e "${GREEN}✅ Lanzando scrcpy por USB...${NC}"
    echo -e "${BLUE}📸 Auto-refresh de medios activado${NC}"
    echo ""
    
    # Aplicar brillo bajo antes de iniciar
    set_low_brightness

    # Construir comando para USB
    CMD="scrcpy -b$BITRATE -m$MAX_SIZE --keyboard=$KEYBOARD --push-target=$PUSH_TARGET"
    
    [ "$STAY_AWAKE" = true ] && CMD="$CMD --stay-awake"
    
    # Usar script para capturar output sin buffering
    TMPLOG=$(mktemp)
    
    (
        sleep 1
        tail -f "$TMPLOG" 2>/dev/null | while IFS= read -r line; do
            if [[ "$line" == *"successfully pushed to"* ]]; then
                echo -e "${GREEN}📸 Refrescando galería...${NC}"
                adb shell "am broadcast -a android.intent.action.MEDIA_SCANNER_SCAN_FILE -d 'file://${PUSH_TARGET}'" >/dev/null 2>&1
            fi
        done
    ) &
    MONITOR_PID=$!
    
    script -q -F "$TMPLOG" $CMD
    
    kill $MONITOR_PID 2>/dev/null
    wait $MONITOR_PID 2>/dev/null
    rm -f "$TMPLOG"
}

get_ip_from_usb() {
    adb shell ip addr show wlan0 2>/dev/null | grep 'inet ' | awk '{print $2}' | cut -d/ -f1
}

fresh_connect() {
    local ip=$1
    local TMPFILE=$(mktemp)
    
    adb kill-server >/dev/null 2>&1
    adb start-server >/dev/null 2>&1
    
    # Ejecutar adb connect en background con timeout de 5 segundos
    ( adb connect "$ip:$PORT" > "$TMPFILE" 2>&1 ) &
    local PID=$!
    
    # Esperar máximo 5 segundos
    local COUNT=0
    while kill -0 $PID 2>/dev/null && [ $COUNT -lt 5 ]; do
        sleep 1
        COUNT=$((COUNT + 1))
    done
    
    # Si sigue corriendo, matarlo
    kill $PID 2>/dev/null
    wait $PID 2>/dev/null
    
    # Leer resultado
    RESULT=$(cat "$TMPFILE")
    rm -f "$TMPFILE"
    
    echo "$RESULT" | grep -q "connected"
}

launch_scrcpy() {
    echo -e "${GREEN}✅ Lanzando scrcpy por WiFi...${NC}"
    echo -e "${BLUE}📸 Auto-refresh de medios activado${NC}"
    echo ""
    
    # Aplicar brillo bajo antes de iniciar
    set_low_brightness

    # Construir comando con opciones configurables
    CMD="scrcpy --select-tcpip -b$BITRATE -m$MAX_SIZE --keyboard=$KEYBOARD --push-target=$PUSH_TARGET"
    
    [ "$STAY_AWAKE" = true ] && CMD="$CMD --stay-awake"
    
    # Usar script para capturar output sin buffering en macOS
    # El comando script fuerza un pseudo-terminal que no buferea
    TMPLOG=$(mktemp)
    
    # Ejecutar scrcpy en un pseudo-terminal y monitorear en background
    (
        # Esperar a que se cree el log
        sleep 1
        tail -f "$TMPLOG" 2>/dev/null | while IFS= read -r line; do
            if [[ "$line" == *"successfully pushed to"* ]]; then
                echo -e "${GREEN}📸 Refrescando galería...${NC}"
                adb shell "am broadcast -a android.intent.action.MEDIA_SCANNER_SCAN_FILE -d 'file://${PUSH_TARGET}'" >/dev/null 2>&1
            fi
        done
    ) &
    MONITOR_PID=$!
    
    # Ejecutar scrcpy con script para output sin buffer
    script -q -F "$TMPLOG" $CMD
    
    # Limpiar
    kill $MONITOR_PID 2>/dev/null
    wait $MONITOR_PID 2>/dev/null
    rm -f "$TMPLOG"
}

wait_for_usb() {
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}  📲 CONECTA TU ANDROID POR USB${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "  • Depuración USB activada"
    echo -e "  • Acepta el diálogo en el teléfono"
    echo -e "  • Teléfono conectado a WiFi"
    echo ""
    echo -e "${BLUE}  Esperando USB... (Ctrl+C para cancelar)${NC}"
    
    adb kill-server >/dev/null 2>&1
    
    while true; do
        adb start-server >/dev/null 2>&1
        USB=$(adb devices | grep -v "List" | grep "device$" | grep -v ":")
        if [ -n "$USB" ]; then
            echo -e "\n${GREEN}  ✅ ¡Dispositivo detectado!${NC}"
            return 0
        fi
        sleep 1
        echo -n "."
    done
}

setup_wifi_from_usb() {
    NEW_IP=$(get_ip_from_usb)
    
    if [ -z "$NEW_IP" ]; then
        echo -e "${RED}❌ No se pudo obtener IP. ¿WiFi activado en el teléfono?${NC}"
        return 1
    fi
    
    echo -e "${GREEN}📶 IP: ${NEW_IP}${NC}"
    
    echo -e "${YELLOW}🔄 Activando modo WiFi...${NC}"
    adb tcpip $PORT >/dev/null 2>&1
    echo -e "${YELLOW}   Esperando 4 segundos...${NC}"
    sleep 4
    
    if fresh_connect "$NEW_IP"; then
        echo "$NEW_IP" > "$CONFIG_FILE"
        echo -e "${GREEN}💾 IP guardada${NC}"
        launch_scrcpy
        return 0
    else
        echo -e "${RED}❌ No se pudo conectar por WiFi${NC}"
        return 1
    fi
}
# =============================================================================
# MAIN LOOP
# =============================================================================

# Guardar brillo original y configurar trap para cleanup
store_brightness
trap cleanup_on_exit EXIT

# Verificar ADB
check_adb

# Mostrar menú de selección al inicio
select_connection_mode

if [ "$CONNECTION_MODE" = "usb" ]; then
    # =========================================================================
    # MODO USB
    # =========================================================================
    while true; do
        show_header
        echo -e "${BLUE}📲 Modo USB${NC}"
        echo ""
        
        echo -e "${YELLOW}🔍 Buscando dispositivo USB...${NC}"
        adb kill-server >/dev/null 2>&1
        adb start-server >/dev/null 2>&1
        
        USB=$(adb devices | grep -v "List" | grep "device$" | grep -v ":")
        
        if [ -z "$USB" ]; then
            wait_for_usb
        fi
        
        echo -e "${GREEN}✅ Dispositivo USB encontrado${NC}"
        launch_scrcpy_usb
        
        echo ""
        echo -e "${YELLOW}¿Reconectar? (s/n)${NC}"
        read -r resp
        [[ "$resp" != "s" && "$resp" != "S" ]] && exit 0
    done
else
    # =========================================================================
    # MODO WIFI (comportamiento actual)
    # =========================================================================
    while true; do
        show_header
        echo -e "${GREEN}📶 Modo WiFi${NC}"
        echo ""
        
        if [ -f "$CONFIG_FILE" ]; then
            SAVED_IP=$(cat "$CONFIG_FILE")
            echo -e "${YELLOW}📋 Conectando a IP guardada: ${SAVED_IP}${NC}"
            
            if fresh_connect "$SAVED_IP"; then
                echo -e "${GREEN}✅ Conectado!${NC}"
                launch_scrcpy
                
                echo ""
                echo -e "${YELLOW}¿Reconectar? (s/n)${NC}"
                read -r resp
                [[ "$resp" != "s" && "$resp" != "S" ]] && exit 0
                continue
            fi
            
            echo -e "${RED}❌ IP guardada no responde${NC}"
            echo ""
        fi
        
        echo -e "${YELLOW}🔍 Buscando USB para obtener IP...${NC}"
        adb kill-server >/dev/null 2>&1
        adb start-server >/dev/null 2>&1
        
        USB=$(adb devices | grep -v "List" | grep "device$" | grep -v ":")
        
        if [ -z "$USB" ]; then
            wait_for_usb
        fi
        
        if setup_wifi_from_usb; then
            echo ""
            echo -e "${YELLOW}¿Reconectar? (s/n)${NC}"
            read -r resp
            [[ "$resp" != "s" && "$resp" != "S" ]] && exit 0
        else
            echo ""
            echo -e "${YELLOW}ENTER para reintentar...${NC}"
            read -r
        fi
    done
fi
