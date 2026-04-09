#!/bin/bash
# =============================================================================
# refresh-media.sh - Fuerza escaneo de medios en Android
# =============================================================================
# Ejecutar después de hacer push de archivos para que aparezcan en Instagram/Galería

PUSH_TARGET="/sdcard/Pictures/Push"

# Colores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}📸 Escaneando medios en: ${PUSH_TARGET}${NC}"

# Forzar escaneo de la carpeta (funciona en Android 10+)
adb shell "am broadcast -a android.intent.action.MEDIA_SCANNER_SCAN_FILE -d 'file://${PUSH_TARGET}'" >/dev/null 2>&1

# Método alternativo más agresivo (escanea cada archivo)
adb shell "find ${PUSH_TARGET} -type f -name '*.jpg' -o -name '*.jpeg' -o -name '*.png' -o -name '*.mp4' -o -name '*.mov' -o -name '*.gif' 2>/dev/null" | while read file; do
    adb shell "am broadcast -a android.intent.action.MEDIA_SCANNER_SCAN_FILE -d 'file://${file}'" >/dev/null 2>&1
done

echo -e "${GREEN}✅ ¡Listo! Los archivos deberían aparecer en Instagram/Galería ahora${NC}"
