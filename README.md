# scrcpy-mac-app

⚡️ **Tu Android en la Mac** — Experiencia similar a Continuity para Android

Arrastrá archivos, usá tu teclado y mouse, copiá y pegá entre dispositivos, y más.

🎯 **Descargar**: [Latest Release](https://github.com/Chugeno/scrcpy-mac-app/releases/latest)

---

Este script configura y ejecuta scrcpy con opciones optimizadas para que no tengas que acordarte de nada.

## Configuraciones por defecto

| Config | Valor | Descripción |
|--------|-------|-------------|
| Bitrate | 2M | Balance calidad/lag por WiFi |
| Resolución | 800px | Rendimiento óptimo |
| Brillo | ~4% | Bajo al conectar, restaurado al salir |
| Teclado | uhid | Soporte completo de teclado físico |
| Stay awake | true | Teléfono no duerme mientras scrcpy corre |

## Características

- ✅ Conexión WiFi o USB (elegir al inicio)
- ✅ Brillo bajo automático (~4%) al conectar
- ✅ Brillo restaurado al salir
- ✅ Auto-refresh de galería cuando subís archivos arrastrando
- ✅ Detecta si ADB está corriendo y reinicia automáticamente
- ✅ Desconexión USB automática al usar WiFi (evita conflictos)

## Requisitos

- [scrcpy](https://github.com/Genymobile/scrcpy) instalado (`brew install scrcpy`)
- Teléfono con depuración USB activada
- Teléfono en la misma red WiFi que la Mac

## Uso

```bash
git clone https://github.com/Chugeno/scrcpy-mac-app.git ~/scrcpy-mac-app
cd ~/scrcpy-mac-app
./android-wifi.sh
```

1. Conectar el teléfono por USB (la primera vez)
2. Ejecutar `./android-wifi.sh`
3. Elegir WiFi (default) o USB
4. Si es WiFi, el script obtiene la IP automáticamente
5. Usar scrcpy normalmente
6. **CERRAR scrcpy antes de desconectar** (Ctrl+C)
7. El brillo se restaura automáticamente

## Solución de problemas

### "ADB server didn't ACK"

Otro programa está usando ADB (Android Studio, etc.). El script lo detecta y reinicia automáticamente.

### El brillo no baja

Los dispositivos necesitan permisos. Probá:
```bash
adb shell settings put system screen_brightness_mode 0
adb shell settings put system screen_brightness 10
```

### La pantalla quedó apagada

Siempre cerrá scrcpy (Ctrl+C) antes de desconectar. Si quedó apagada:
```bash
adb shell input keyevent 26
```