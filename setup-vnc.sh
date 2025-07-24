#!/bin/bash

# =============================================================================
# Script AUTOMÁTICO de Configuración VNC para Ubuntu Server
# Convierte XRDP a VNC con XFCE4 optimizado - SIN INTERACCIÓN
# Versión: 2.0 - Completamente automático
# =============================================================================

echo "🚀 Iniciando configuración AUTOMÁTICA de VNC..."

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuraciones por defecto (EDITABLE)
VNC_PASSWORD="123456789"  # Cambiar por tu contraseña preferida
VNC_GEOMETRY="1920x1080"
VNC_DEPTH="24"
VNC_DISPLAY=":1"

# Función para imprimir con colores
print_status() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Función para manejar errores
handle_error() {
    print_error "Error en línea $1. Continuando..."
    # No salir, solo continuar
}

trap 'handle_error $LINENO' ERR
set +e  # No salir en errores, solo reportar

# =============================================================================
# 1. LIMPIEZA INICIAL Y REMOCIÓN DE XRDP
# =============================================================================

echo -e "${BLUE}🧹 Paso 1: Limpieza inicial${NC}"

# Remover XRDP si existe
if systemctl is-active --quiet xrdp 2>/dev/null; then
    print_warning "Deteniendo y removiendo XRDP..."
    sudo systemctl stop xrdp 2>/dev/null || true
    sudo systemctl disable xrdp 2>/dev/null || true
    sudo apt remove xrdp -y 2>/dev/null || true
    sudo apt autoremove -y 2>/dev/null || true
fi

# Limpiar procesos VNC de forma más segura
print_info "Limpiando procesos VNC existentes..."
sudo pkill -f "vnc" 2>/dev/null || true
sudo pkill -f "Xvnc" 2>/dev/null || true
sudo pkill -f "tigervnc" 2>/dev/null || true

# Limpiar archivos de configuración antiguos
rm -rf ~/.vnc/*.log ~/.vnc/*.pid ~/.vnc/passwd 2>/dev/null || true

print_status "Limpieza completada"

# =============================================================================
# 2. INSTALACIÓN DE PAQUETES
# =============================================================================

echo -e "${BLUE}📦 Paso 2: Instalación de paquetes${NC}"

print_info "Actualizando repositorios..."
sudo apt update -y

print_info "Instalando componentes base..."
sudo DEBIAN_FRONTEND=noninteractive apt install -y \
    xfce4 \
    xfce4-goodies \
    xfce4-session \
    xfce4-settings \
    xfce4-terminal \
    xterm \
    tigervnc-standalone-server \
    tigervnc-common \
    tigervnc-tools \
    dbus \
    dbus-x11 \
    at-spi2-core \
    x11-xserver-utils \
    expect

# Remover TightVNC si existe (sin error si no existe)
sudo apt remove tightvncserver -y 2>/dev/null || true
sudo apt autoremove -y

print_status "Paquetes instalados correctamente"

# =============================================================================
# 3. CONFIGURACIÓN DE VNC
# =============================================================================

echo -e "${BLUE}⚙️  Paso 3: Configuración de VNC${NC}"

# Crear directorio .vnc si no existe
mkdir -p ~/.vnc

print_info "Creando archivo xstartup optimizado..."
cat > ~/.vnc/xstartup << 'EOF'
#!/bin/bash

# Limpia variables de sesión problemáticas
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS

# Configura el display
export DISPLAY=:1

# Configura el fondo
xsetroot -solid '#2E3436'

# Inicia el bus de D-Bus para la sesión
eval `dbus-launch --sh-syntax`

# Exporta las variables necesarias
export DBUS_SESSION_BUS_ADDRESS
export DBUS_SESSION_BUS_PID

# Inicia XFCE4 con todas las variables configuradas
exec startxfce4
EOF

chmod +x ~/.vnc/xstartup

print_info "Creando archivo de configuración VNC..."
cat > ~/.vnc/config << EOF
geometry=${VNC_GEOMETRY}
depth=${VNC_DEPTH}
localhost=no
pixelformat=rgb888
dpi=96
EOF

print_status "Archivos de configuración creados"

# =============================================================================
# 4. CONFIGURACIÓN DE FIREWALL
# =============================================================================

echo -e "${BLUE}🔥 Paso 4: Configuración de firewall${NC}"

print_info "Configurando UFW..."
sudo ufw allow 5901/tcp
echo "y" | sudo ufw --force enable 2>/dev/null || sudo ufw --force enable 

print_info "Configurando iptables..."
sudo iptables -A INPUT -p tcp --dport 5901 -j ACCEPT 2>/dev/null || true

print_status "Firewall configurado para puerto 5901"

# =============================================================================
# 5. CONFIGURACIÓN AUTOMÁTICA DE CONTRASEÑA
# =============================================================================

echo -e "${BLUE}🔐 Paso 5: Configuración automática de contraseña VNC${NC}"

print_info "Configurando contraseña VNC automáticamente..."

# Usar expect para automatizar vncpasswd
expect << EOF
spawn vncpasswd
expect "Password:"
send "${VNC_PASSWORD}\r"
expect "Verify:"
send "${VNC_PASSWORD}\r"
expect "Would you like to enter a view-only password (y/n)?"
send "n\r"
expect eof
EOF

print_status "Contraseña VNC configurada automáticamente"

# =============================================================================
# 6. INICIO DEL SERVIDOR VNC
# =============================================================================

echo -e "${BLUE}🚀 Paso 6: Iniciando servidor VNC${NC}"

print_info "Iniciando VNC en display ${VNC_DISPLAY}..."

# Asegurar que no hay VNC corriendo en el display
vncserver -kill ${VNC_DISPLAY} 2>/dev/null || true

# Iniciar VNC con configuración optimizada
vncserver ${VNC_DISPLAY} -geometry ${VNC_GEOMETRY} -depth ${VNC_DEPTH} -localhost no

# Esperar a que inicie
sleep 5

# Verificar que esté corriendo
if vncserver -list | grep -q "5901"; then
    print_status "Servidor VNC iniciado correctamente"
else
    print_error "Error al iniciar VNC. Intentando de nuevo..."
    sleep 3
    vncserver ${VNC_DISPLAY} -localhost no
    sleep 3
    if vncserver -list | grep -q "5901"; then
        print_status "Servidor VNC iniciado en segundo intento"
    else
        print_error "Fallo crítico al iniciar VNC. Logs:"
        cat ~/.vnc/*.log | tail -10
        exit 1
    fi
fi

# =============================================================================
# 7. VERIFICACIONES FINALES
# =============================================================================

echo -e "${BLUE}🔍 Paso 7: Verificaciones finales${NC}"

# Verificar puerto
print_info "Verificando puerto 5901..."
sleep 2

if ss -tlnp | grep -q "0.0.0.0:5901"; then
    print_status "Puerto 5901 escuchando en todas las interfaces ✓"
elif ss -tlnp | grep -q "127.0.0.1:5901"; then
    print_warning "Puerto solo en localhost. Corrigiendo..."
    vncserver -kill ${VNC_DISPLAY}
    sleep 2
    vncserver ${VNC_DISPLAY} -localhost no
    sleep 3
    if ss -tlnp | grep -q "0.0.0.0:5901"; then
        print_status "Puerto corregido - ahora escucha en todas las interfaces ✓"
    else
        print_error "No se pudo corregir el puerto"
    fi
else
    print_error "Puerto 5901 no encontrado"
fi

# Obtener IP del servidor
print_info "Obteniendo IP pública del servidor..."
SERVER_IP=$(curl -s --max-time 10 ifconfig.me 2>/dev/null || curl -s --max-time 10 icanhazip.com 2>/dev/null || hostname -I | awk '{print $1}')

# =============================================================================
# 8. CREAR SERVICIO SYSTEMD AUTOMÁTICAMENTE
# =============================================================================

echo -e "${BLUE}🔧 Paso 8: Creando servicio systemd${NC}"

print_info "Creando servicio systemd para auto-inicio..."

sudo tee /etc/systemd/system/vncserver@.service > /dev/null << EOF
[Unit]
Description=Start TigerVNC server at startup
After=syslog.target network.target

[Service]
Type=forking
User=$USER
Group=$USER
WorkingDirectory=$HOME

PIDFile=$HOME/.vnc/%H:%i.pid
ExecStartPre=-/usr/bin/vncserver -kill :%i > /dev/null 2>&1
ExecStart=/usr/bin/vncserver -depth ${VNC_DEPTH} -geometry ${VNC_GEOMETRY} -localhost no :%i
ExecStop=/usr/bin/vncserver -kill :%i

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable vncserver@1.service

print_status "Servicio systemd creado y habilitado"

# =============================================================================
# 9. SCRIPT DE ADMINISTRACIÓN
# =============================================================================

echo -e "${BLUE}📝 Paso 9: Creando script de administración${NC}"

cat > ~/vnc-admin.sh << 'EOF'
#!/bin/bash

# Script de administración VNC

case $1 in
    start)
        echo "🚀 Iniciando VNC..."
        vncserver :1
        ;;
    stop)
        echo "🛑 Deteniendo VNC..."
        vncserver -kill :1
        ;;
    restart)
        echo "🔄 Reiniciando VNC..."
        vncserver -kill :1
        sleep 2
        vncserver :1
        ;;
    status)
        echo "📊 Estado de VNC:"
        vncserver -list
        ss -tlnp | grep 5901
        ;;
    logs)
        echo "📋 Logs de VNC:"
        cat ~/.vnc/*.log | tail -20
        ;;
    password)
        echo "🔐 Cambiando contraseña..."
        vncpasswd
        ;;
    *)
        echo "Uso: $0 {start|stop|restart|status|logs|password}"
        exit 1
        ;;
esac
EOF

chmod +x ~/vnc-admin.sh

print_status "Script de administración creado: ~/vnc-admin.sh"

# =============================================================================
# 10. INFORMACIÓN FINAL
# =============================================================================

echo ""
echo -e "${GREEN}🎉 ¡Configuración de VNC completada exitosamente!${NC}"
echo ""
echo -e "${BLUE}📋 INFORMACIÓN DE CONEXIÓN:${NC}"
echo -e "   ${YELLOW}Dirección:${NC} $SERVER_IP:5901"
echo -e "   ${YELLOW}Puerto:${NC} 5901"
echo -e "   ${YELLOW}Display:${NC} :1"
echo -e "   ${YELLOW}Contraseña:${NC} $VNC_PASSWORD"
echo ""
echo -e "${BLUE}🔧 COMANDOS ÚTILES:${NC}"
echo -e "   ${YELLOW}Administrar VNC:${NC} ~/vnc-admin.sh {start|stop|restart|status|logs|password}"
echo -e "   ${YELLOW}Ver servidores VNC:${NC} vncserver -list"
echo -e "   ${YELLOW}Ver logs:${NC} cat ~/.vnc/*.log"
echo ""
echo -e "${BLUE}☁️  CONFIGURACIÓN EN AZURE:${NC}"
echo -e "   ${YELLOW}1.${NC} Ve al portal de Azure"
echo -e "   ${YELLOW}2.${NC} Selecciona tu VM → Networking"
echo -e "   ${YELLOW}3.${NC} Add inbound port rule → Puerto: 5901, TCP, Any"
echo ""
echo -e "${BLUE}🎯 ESTADO ACTUAL:${NC}"
vncserver -list
echo ""
ss -tlnp | grep 5901 || echo "Puerto no detectado"
echo ""
echo -e "${GREEN}✨ ¡VNC configurado y listo para usar!${NC}"
echo -e "${GREEN}🔄 VNC se iniciará automáticamente al reiniciar el servidor${NC}"
