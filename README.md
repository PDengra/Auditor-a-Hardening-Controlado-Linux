# Auditor-a-Hardening-Controlado-Linux

## 📌 ¿QUÉ HACE ESTE SCRIPT?

Este script es un **auditor + hardener controlado para sistemas Linux**, inspirado en **CIS Benchmarks**, con:

- trazabilidad completa
- baseline persistente
- comparación de cambios (diff)
- firma de integridad (SHA256)
- notificaciones por email y Telegram

⚠️ **No es un hardener automático a ciegas**  
⚠️ **No es solo auditoría pasiva**  

Es un **punto intermedio profesional**, pensado para entornos reales.

---

## 🧠 Modo de funcionamiento

El script tiene **dos modos de operación**:

### 🔍 Modo `--audit`

- ❌ **NO cambia nada del sistema**
- Solo:
  - comprueba configuraciones
  - genera un informe
  - compara con baseline
  - firma el resultado
  - envía notificaciones

👉 **Este es el modo que DEBES usar siempre primero.**

Ejemplo:
```bash
sudo ./audit_harden_pro_notify.sh --audit
````
## 🔧 Modo `--harden`

✔ Aplica **cambios controlados** en el sistema.

Solo actúa sobre:
- SSH
- sysctl
- firewall

Cada cambio:
- queda registrado en el informe
- es trazable
- es reproducible

👉 Pensado para:
- servidores nuevos
- hardening progresivo
- entornos controlados

Ejemplo de uso:
```bash
sudo ./audit_harden_pro_notify.sh --harden
```
##🔎 ¿QUÉ COMPRUEBA EXACTAMENTE?
🖥️ Sistema
  - Sistema operativo
  - Kernel
  - Virtualización

🔐 SSH (CIS básico)
  - PermitRootLogin no
  - PasswordAuthentication no

🧠 Kernel / sysctl
  - ASLR activado
  - IP forwarding deshabilitado

🔥 Firewall
  - UFW activo

👤 Usuarios
  - Usuarios con shell válida
  - Usuarios con UID 0

🧾 Baseline + Diff
  Primera ejecución
    - Se crea un baseline del sistema
  Ejecuciones posteriores
    - Se compara el estado actual con el baseline
    - Se genera un diff
👉 Permite detectar:
  - cambios no autorizados
  - drift de configuración
  - regresiones de seguridad

🔐 Firma SHA256
Cada informe se firma automáticamente:
````bash
sha256sum report.log > report.log.sha256
````
Sirve para:
- garantizar integridad
- auditorías formales
- cadena de custodia
- demostrar que el informe no fue alterado

📧📲 Notificaciones
Al finalizar la ejecución:
  - 📧 Se envía el informe completo por email
  - 📲 Se envía el informe adjunto por Telegram
Además, se registra en el propio informe si:
  - el envío fue correcto
  - falló
  - no estaba configurado
👉 Nada queda sin traza.

⚙️ CONFIGURACIÓN

Antes de usar el script revisa estas 3 zonas clave.

🔔 1. Configuración de notificaciones
📧 Email
````bash
EMAIL="admin@tuservidor.com"
````
Requisitos:
  - msmtp instalado y configurado
  - relay SMTP funcional
  - Instalación ejemplo (Debian/Ubuntu):
````bash
sudo apt install msmtp msmtp-mta
````

📲 Telegram
````bash
TELEGRAM_BOT_TOKEN="123456:ABCDEF..."
TELEGRAM_CHAT_ID="987654321"
````
Pasos:
  - Crear un bot con @BotFather
  - Obtener el token
  - Enviar un mensaje al bot
  - Obtener el chat_id

🧪 2. Primer uso (MUY IMPORTANTE)

❌ NUNCA empieces con --harden

Primero ejecuta:
````bash
sudo ./audit_harden_pro_notify.sh --audit
````
Revisa:
  - informe generado
  - diff
  - notificaciones

🔐 3. Permisos
El script necesita root para:
  - leer configuraciones
  - ejecutar sysctl
  - modificar SSH / firewall (modo --harden)

Ejemplo:
````bash
sudo ./audit_harden_pro_notify.sh --audit
````

🚀 AUTOMATIZACIÓN (OPCIONAL)

Ejemplo de ejecución semanal con cron:
````bash
0 3 * * 0 root /path/audit_harden_pro_notify.sh --audit
````

⚠️ DISCLAIMER

Este script puede modificar la configuración del sistema cuando se usa --harden.

  - 👉 Úsalo bajo tu responsabilidad
  - 👉 Prueba siempre en entornos no productivos primero
