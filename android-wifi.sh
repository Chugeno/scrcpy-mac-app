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

# Estado de conexión
USB_WAS_CONNECTED=false

# Serial del dispositivo actual (para usar adb -s)
DEVICE_SERIAL=""

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
    # Intentar usar ADB existente
    if adb get-state 1>/dev/null 2>&1; then
        echo -e "${GREEN}✅ ADB funcionando${NC}"
        return 0
    fi
    
    # Si falla, matar y reiniciar automáticamente
    echo -e "${YELLOW}🔄 ADB no responde, reiniciando...${NC}"
    adb kill-server 2>/dev/null
    sleep 2
    adb start-server
    
    # Verificar si funcionó
    if adb get-state 1>/dev/null 2>&1; then
        echo -e "${GREEN}✅ ADB reiniciado${NC}"
        return 0
    fi
    
    echo -e "${RED}❌ ADB no disponible${NC}"
    return 1
}

store_brightness() {
    ORIGINAL_BRIGHTNESS=$(adb -s "$DEVICE_SERIAL" shell settings get system screen_brightness 2>/dev/null | tr -d '\r')
    ORIGINAL_BRIGHTNESS_MODE=$(adb -s "$DEVICE_SERIAL" shell settings get system screen_brightness_mode 2>/dev/null | tr -d '\r')
    [ -z "$ORIGINAL_BRIGHTNESS" ] && ORIGINAL_BRIGHTNESS=128
    [ -z "$ORIGINAL_BRIGHTNESS_MODE" ] && ORIGINAL_BRIGHTNESS_MODE=1
}

set_low_brightness() {
    echo -e "${YELLOW}🔅 Aplicando brillo bajo...${NC}"
    adb -s "$DEVICE_SERIAL" shell settings put system screen_brightness_mode 0
    adb -s "$DEVICE_SERIAL" shell settings put system screen_brightness "$LOW_BRIGHTNESS"
    NEW_BRIGHTNESS=$(adb -s "$DEVICE_SERIAL" shell settings get system screen_brightness | tr -d '\r')
    echo -e "${YELLOW}🔅 Brillo: $NEW_BRIGHTNESS${NC}"
}

restore_brightness() {
    if [ -n "$ORIGINAL_BRIGHTNESS" ] && [ -n "$DEVICE_SERIAL" ]; then
        adb -s "$DEVICE_SERIAL" shell settings put system screen_brightness "$ORIGINAL_BRIGHTNESS" 2>/dev/null
        echo -e "${YELLOW}🔅 Brillo restaurado: $ORIGINAL_BRIGHTNESS${NC}"
    fi
    if [ -n "$ORIGINAL_BRIGHTNESS_MODE" ] && [ -n "$DEVICE_SERIAL" ]; then
        adb -s "$DEVICE_SERIAL" shell settings put system screen_brightness_mode "$ORIGINAL_BRIGHTNESS_MODE" 2>/dev/null
    fi
}

cleanup_on_exit() {
    restore_brightness
    # No reconectamos nada - si quiere USB, que conecte el cable físico
    # El script detectará automáticamente el modo de conexión la próxima vez
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
    
    # Detectar serial USB - buscar dispositivos que NO tengan ":" (son físicos, no TCPIP)
    USB_SERIAL=$(adb devices 2>/dev/null | grep -v "List" | grep "device$" | grep -v ":" | head -1 | awk '{print $1}')
    if [ -z "$USB_SERIAL" ]; then
        echo -e "${RED}❌ No se detectó dispositivo USB${NC}"
        return 1
    fi
    DEVICE_SERIAL="$USB_SERIAL"
    echo -e "${BLUE}📱 Usando: $USB_SERIAL${NC}"
    
    # Limpiar conexiones WiFi previas para evitar "more than one device"
    adb disconnect 127.0.0.1:$PORT 2>/dev/null
    sleep 1
    
    # Aplicar brillo bajo antes de iniciar
    set_low_brightness

    # Construir comando para USB
    CMD="scrcpy -s $DEVICE_SERIAL -b$BITRATE -m$MAX_SIZE --keyboard=$KEYBOARD --push-target=$PUSH_TARGET"
    
    [ "$STAY_AWAKE" = true ] && CMD="$CMD --stay-awake"
    
    # Usar script para capturar output sin buffering
    TMPLOG=$(mktemp)
    
    (
        sleep 1
        tail -f "$TMPLOG" 2>/dev/null | while IFS= read -r line; do
            if [[ "$line" == *"successfully pushed to"* ]]; then
                echo -e "${GREEN}📸 Refrescando galería...${NC}"
                adb -s "$DEVICE_SERIAL" shell "am broadcast -a android.intent.action.MEDIA_SCANNER_SCAN_FILE -d 'file://${PUSH_TARGET}'" >/dev/null 2>&1
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
    
    if echo "$RESULT" | grep -q "connected"; then
        # Guardar el serial del dispositivo conectado por WiFi
        DEVICE_SERIAL="${ip}:${PORT}"
        return 0
    fi
    return 1
}

launch_scrcpy() {
    echo -e "${GREEN}✅ Lanzando scrcpy por WiFi...${NC}"
    echo -e "${BLUE}📸 Auto-refresh de medios activado${NC}"
    echo ""
    
    # Limpiar cualquier conexión USB previa para evitar "more than one device"
    USB_CONNECTED=$(adb devices 2>/dev/null | grep -v "List" | grep "device$" | grep -v ":" | grep "usb" | wc -l | tr -d ' ')
    if [ "$USB_CONNECTED" -gt 0 ]; then
        echo -e "${BLUE}🔌 Desconectando USB para evitar conflictos...${NC}"
        # Solo desconectar USB físicos, no el WiFi que ya está en DEVICE_SERIAL
        for dev in $(adb devices 2>/dev/null | grep -v "List" | grep "device$" | grep -v ":" | grep "usb" | awk '{print $1}'); do
            adb -s "$dev" disconnect 2>/dev/null
        done
        sleep 1
    fi
    
    # Aplicar brillo bajo antes de iniciar
    set_low_brightness

    # Construir comando con opciones configurables
    # DEVICE_SERIAL ya es la IP:5555, así que solo usamos -s (sin --select-tcpip)
    CMD="scrcpy -s $DEVICE_SERIAL -b$BITRATE -m$MAX_SIZE --keyboard=$KEYBOARD --push-target=$PUSH_TARGET"
    
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
                adb -s "$DEVICE_SERIAL" shell "am broadcast -a android.intent.action.MEDIA_SCANNER_SCAN_FILE -d 'file://${PUSH_TARGET}'" >/dev/null 2>&1
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
        sleep 1
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
    # Verificar si hay USB conectado antes de establecer WiFi
    USB_DEVICE=$(adb devices | grep -v "List" | grep "device$" | grep -v ":" | grep "usb" | head -1)
    if [ -n "$USB_DEVICE" ]; then
        USB_WAS_CONNECTED=true
        echo -e "${BLUE}🔌 USB detectado, se restaurará al terminar${NC}"
    fi
    
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
        
        # Desconectar USB para evitar "more than one device"
        if [ "$USB_WAS_CONNECTED" = true ]; then
            echo -e "${BLUE}🔌 Desconectando USB...${NC}"
            adb disconnect 2>/dev/null
            sleep 1
        fi
        
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
        
        # Solo reiniciar ADB si no hay dispositivos
        USB_CHECK=$(adb devices 2>/dev/null | grep -v "List" | grep "device$" | grep -v ":")
        if [ -z "$USB_CHECK" ]; then
            echo -e "${YELLOW}🔄 Reiniciando ADB...${NC}"
            adb kill-server >/dev/null 2>&1
            adb start-server >/dev/null 2>&1
            sleep 2
        fi
        
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
