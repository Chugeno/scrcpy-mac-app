# scrcpy-mac-app

Launcher de scrcpy para macOS con gestión de brillo bajo y auto-refresh de medios.

## Opciones de uso

### Opción 1: Descargar el .app (recomendado)

```bash
# Descargar el release desde GitHub
# Ir a: https://github.com/tuuser/scrcpy-mac-app/releases
# Descargar Android.app.zip y descomprimir en /Applications
```

### Opción 2: Ejecutar el script manualmente

```bash
# Clonar el repo
git clone https://github.com/tuuser/scrcpy-mac-app.git ~/scrcpy-mac-app

# Ejecutar
cd ~/scrcpy-mac-app
./android-wifo.sh
```

## Características

- ✅ Conexión WiFi o USB (elegir al inicio)
- ✅ Brillo bajo automático (~4%) al conectar
- ✅ Brillo restaurado al salir
- ✅ Auto-refresh de galería cuando subís archivos arrastrando
- ✅ Detecta si ADB está corriendo y pregunta qué hacer

## Requisitos

- [scrcpy](https://github.com/Genymobile/scrcpy) instalado (`brew install scrcpy`)
- ADB-enabled phone
- Teléfono en la misma red WiFi

## Uso

1. Conectar el teléfono por USB (la primera vez)
2. Ejecutar `android-wifi.sh`
3. Elegir WiFi o USB
4. Si es WiFi, el script obtiene la IP y configura TCPIP
5. Usar scrcpy normalmente
6. **CERRAR scrcpy antes de desconectar el cable**
7._LISTO El brillo se restaura automáticamente

## Solución de problemas

### "ADB server didn't ACK"

Otro programa está usando ADB (Android Studio, etc.). Cerralo o elegí "Matar ADB" en el menú.

### El brillo no baja

某些 dispositivos necesitan permisos. Probá:
```bash
adb shell settings put system screen_brightness_mode 0
adb shell settings put system screen_brightness 10
```

### La pantalla quedó apagada

Always cerrá scrcpy (Ctrl+C) antes de desconectar. Si quedó apagada:
```bash
adb shell input keyevent 26
```