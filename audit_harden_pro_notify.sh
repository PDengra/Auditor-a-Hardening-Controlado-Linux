#!/usr/bin/env bash
# ============================================================
# Auditoría + Hardening Controlado Linux (CIS-oriented)
# Autor: Pablo Dengra
# ============================================================

set -euo pipefail

############################
# CONFIGURACIÓN
############################
DATE="$(date +%Y%m%d_%H%M%S)"
HOST="$(hostname)"
BASE_DIR="$HOME/audit_hardening"
REPORT_DIR="$BASE_DIR/reports"
BASELINE_DIR="$BASE_DIR/baseline"

mkdir -p "$REPORT_DIR" "$BASELINE_DIR"

MODE="audit"              # audit | harden
PROFILE="auto"            # auto | server | workstation
TIMEOUT=5

REPORT="$REPORT_DIR/report_${HOST}_${DATE}.log"
BASELINE_FILE="$BASELINE_DIR/baseline_${HOST}.log"
DIFF_FILE="$REPORT_DIR/diff_${HOST}_${DATE}.diff"
HASH_FILE="$REPORT.sha256"

# 🔔 NOTIFICACIONES
EMAIL="admin@tuservidor.com"
TELEGRAM_BOT_TOKEN="AQUÍ TU BOT TOKEN"
TELEGRAM_CHAT_ID="AQUÍ TU CHAT ID"

############################
# ARGUMENTOS
############################
for arg in "$@"; do
  case "$arg" in
    --audit) MODE="audit" ;;
    --harden) MODE="harden" ;;
    --profile=*) PROFILE="${arg#*=}" ;;
    *) echo "Uso: $0 [--audit|--harden] [--profile=server|workstation|auto]"; exit 1 ;;
  esac
done

############################
# PERFIL AUTOMÁTICO
############################
if [[ "$PROFILE" == "auto" ]]; then
  if systemd-detect-virt &>/dev/null; then
    PROFILE="server"
  else
    PROFILE="workstation"
  fi
fi

############################
# FUNCIONES
############################
log() { echo -e "$1" >> "$REPORT"; }

section() {
  log "\n=================================================="
  log " $1"
  log "=================================================="
}

check() {
  local desc="$1"
  local cmd="$2"

  log "\n[CHECK] $desc"
  timeout "$TIMEOUT" bash -c "$cmd" >> "$REPORT" 2>&1 || log "[FAIL]"
}

harden() {
  local desc="$1"
  local cmd="$2"

  log "\n[HARDEN] $desc"
  if [[ "$MODE" == "harden" ]]; then
    timeout "$TIMEOUT" bash -c "$cmd" >> "$REPORT" 2>&1 || log "[ERROR]"
  else
    log "[SKIPPED - audit mode]"
  fi
}

############################
# CABECERA
############################
{
echo "=================================================="
echo " AUDITORÍA / HARDENING LINUX"
echo " Fecha: $(date)"
echo " Host: $HOST"
echo " Perfil CIS: $PROFILE"
echo " Modo: $MODE"
echo "=================================================="
} > "$REPORT"

############################
# SISTEMA
############################
section "INFORMACIÓN DEL SISTEMA"
check "Sistema operativo" "cat /etc/os-release || uname -a"
check "Kernel" "uname -r"
check "Virtualización" "systemd-detect-virt || echo none"

############################
# SSH (CIS)
############################
section "SSH (CIS)"

check "Root login deshabilitado" \
"grep -q '^PermitRootLogin no' /etc/ssh/sshd_config"

harden "Deshabilitar root por SSH" \
"sed -i 's/^#\\?PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config && systemctl reload sshd"

check "PasswordAuthentication deshabilitado" \
"grep -q '^PasswordAuthentication no' /etc/ssh/sshd_config"

harden "Deshabilitar auth por password" \
"sed -i 's/^#\\?PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config && systemctl reload sshd"

############################
# SYSCTL (CIS)
############################
section "KERNEL / SYSCTL"

check "ASLR habilitado" \
"sysctl kernel.randomize_va_space | grep -q '= 2'"

harden "Habilitar ASLR" \
"sysctl -w kernel.randomize_va_space=2"

check "IP forwarding deshabilitado" \
"sysctl net.ipv4.ip_forward | grep -q '= 0'"

harden "Deshabilitar IP forwarding" \
"sysctl -w net.ipv4.ip_forward=0"

############################
# FIREWALL
############################
section "FIREWALL"

check "UFW activo" \
"ufw status | grep -q active"

harden "Activar firewall UFW" \
"ufw --force enable"

############################
# USUARIOS
############################
section "USUARIOS"

check "Usuarios sin shell válida" \
"awk -F: '\$7 ~ /(nologin|false)/ {print \$1}' /etc/passwd"

check "Usuarios con UID 0" \
"awk -F: '\$3 == 0 {print \$1}' /etc/passwd"

############################
# BASELINE
############################
section "BASELINE"

if [[ ! -f "$BASELINE_FILE" ]]; then
  log "No existe baseline previo, creando..."
  cp "$REPORT" "$BASELINE_FILE"
else
  diff -u "$BASELINE_FILE" "$REPORT" > "$DIFF_FILE" || true
  log "Baseline comparado"
fi

############################
# FIRMA SHA256
############################
section "INTEGRIDAD"
sha256sum "$REPORT" > "$HASH_FILE"
log "Firma SHA256 generada: $HASH_FILE"

############################
# NOTIFICACIONES
############################
section "NOTIFICACIONES"

# 📧 EMAIL
if [[ -n "$EMAIL" ]] && command -v msmtp &>/dev/null; then
  {
    echo "Subject: Auditoría/Harden Linux - $HOST ($MODE)"
    echo "To: $EMAIL"
    echo "Content-Type: text/plain; charset=UTF-8"
    echo
    cat "$REPORT"
  } | msmtp "$EMAIL" \
    && log "[OK] Informe enviado por email a $EMAIL" \
    || log "[ERROR] Fallo en el envío por email"
else
  log "[INFO] Envío por email no configurado o msmtp no disponible"
fi

# 📲 TELEGRAM
if [[ -n "$TELEGRAM_BOT_TOKEN" && -n "$TELEGRAM_CHAT_ID" ]]; then
  if command -v curl &>/dev/null; then
    curl -fsS -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendDocument" \
      -F chat_id="$TELEGRAM_CHAT_ID" \
      -F document=@"$REPORT" \
      -F caption="🛡 Auditoría/Harden Linux
Host: $HOST
Modo: $MODE
Perfil: $PROFILE
Fecha: $(date)" \
      && log "[OK] Informe enviado por Telegram" \
      || log "[ERROR] Fallo en el envío por Telegram"
  else
    log "[ERROR] curl no disponible, no se pudo enviar Telegram"
  fi
else
  log "[INFO] Telegram no configurado (token/chat_id vacíos)"
fi

############################
# FINAL
############################
section "FINAL"
log "Proceso finalizado correctamente"
log "Informe: $REPORT"
log "Baseline: $BASELINE_FILE"
log "Diff: ${DIFF_FILE:-No generado}"
log "SHA256: $HASH_FILE"
