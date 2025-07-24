#!/bin/bash

# =============================================================================
# Script de Configuración VNC para Ubuntu Server
# Convierte XRDP a VNC con XFCE4 optimizado
# =============================================================================

echo "🚀 Iniciando configuración de VNC..."

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# =============================================================================
# 1. LIMPIEZA INICIAL Y REMOCIÓN DE XRDP
# =============================================================================

echo -e "${BLUE}🧹 Paso 1: Limpieza inicial${NC}"

# Remover XRDP si existe
if systemctl is-active --quiet xrdp; then
    print_warning "Deteniendo y removiendo XRDP..."
    sudo systemctl stop xrdp
    sudo systemctl disable xrdp
    sudo apt remove xrdp -y
    sudo apt autoremove -y
fi

# Limpiar procesos VNC existentes
print_info "Limpiando procesos VNC existentes..."
sudo pkill -f vnc 2>/dev/null || true
sudo pkill -f Xvnc 2>/dev/null || true
sudo pkill -f Xtightvnc 2>/dev/null || true

# Limpiar archivos de configuración antiguos
rm -rf ~/.vnc/*.log ~/.vnc/*.pid ~/.vnc/passwd 2>/dev/null || true

print_status "Limpieza completada"

# =============================================================================
# 2. INSTALACIÓN DE PAQUETES
# =============================================================================

echo -e "${BLUE}📦 Paso 2: Instalación de paquetes${NC}"

print_info "Actualizando repositorios..."
sudo apt update

print_info "Instalando componentes base..."
sudo apt install -y \
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
    x11-xserver-utils

# Remover TightVNC si existe
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
cat > ~/.vnc/config << 'EOF'
geometry=1920x1080
depth=24
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
sudo ufw --force enable

print_info "Configurando iptables..."
sudo iptables -A INPUT -p tcp --dport 5901 -j ACCEPT

print_status "Firewall configurado para puerto 5901"

# =============================================================================
# 5. CONFIGURACIÓN DE CONTRASEÑA
# =============================================================================

echo -e "${BLUE}🔐 Paso 5: Configuración de contraseña VNC${NC}"

print_warning "Configura tu contraseña VNC (6-8 caracteres):"
vncpasswd

print_status "Contraseña configurada"

# =============================================================================
# 6. INICIO DEL SERVIDOR VNC
# =============================================================================

echo -e "${BLUE}🚀 Paso 6: Iniciando servidor VNC${NC}"

print_info "Iniciando VNC en display :1..."
vncserver :1

# Verificar que esté corriendo
sleep 3

if vncserver -list | grep -q "5901"; then
    print_status "Servidor VNC iniciado correctamente"
else
    print_error "Error al iniciar VNC. Revisando logs..."
    cat ~/.vnc/*.log | tail -10
    exit 1
fi

# =============================================================================
# 7. VERIFICACIONES FINALES
# =============================================================================

echo -e "${BLUE}🔍 Paso 7: Verificaciones finales${NC}"

# Verificar puerto
print_info "Verificando puerto 5901..."
if ss -tlnp | grep -q "0.0.0.0:5901"; then
    print_status "Puerto 5901 escuchando en todas las interfaces"
elif ss -tlnp | grep -q "127.0.0.1:5901"; then
    print_error "⚠️ Puerto solo escuchando en localhost. Reiniciando..."
    vncserver -kill :1
    vncserver :1
    sleep 2
    if ss -tlnp | grep -q "0.0.0.0:5901"; then
        print_status "Puerto corregido - ahora escucha en todas las interfaces"
    fi
else
    print_error "Puerto 5901 no encontrado"
fi

# Obtener IP del servidor
SERVER_IP=$(curl -s ifconfig.me 2>/dev/null || curl -s icanhazip.com 2>/dev/null || hostname -I | awk '{print $1}')

# =============================================================================
# 8. INFORMACIÓN FINAL
# =============================================================================

echo ""
echo -e "${GREEN}🎉 ¡Configuración de VNC completada exitosamente!${NC}"
echo ""
echo -e "${BLUE}📋 INFORMACIÓN DE CONEXIÓN:${NC}"
echo -e "   ${YELLOW}Dirección:${NC} $SERVER_IP:5901"
echo -e "   ${YELLOW}Puerto:${NC} 5901"
echo -e "   ${YELLOW}Display:${NC} :1"
echo -e "   ${YELLOW}Contraseña:${NC} La que configuraste con vncpasswd"
echo ""
echo -e "${BLUE}🔧 COMANDOS ÚTILES:${NC}"
echo -e "   ${YELLOW}Ver servidores VNC:${NC} vncserver -list"
echo -e "   ${YELLOW}Parar VNC:${NC} vncserver -kill :1"
echo -e "   ${YELLOW}Iniciar VNC:${NC} vncserver :1"
echo -e "   ${YELLOW}Ver logs:${NC} cat ~/.vnc/*.log"
echo -e "   ${YELLOW}Cambiar contraseña:${NC} vncpasswd"
echo ""
echo -e "${BLUE}☁️  CONFIGURACIÓN EN AZURE:${NC}"
echo -e "   ${YELLOW}1.${NC} Ve al portal de Azure"
echo -e "   ${YELLOW}2.${NC} Selecciona tu VM"
echo -e "   ${YELLOW}3.${NC} Ve a 'Networking' → 'Add inbound port rule'"
echo -e "   ${YELLOW}4.${NC} Puerto: 5901, Protocolo: TCP, Origen: Any"
echo ""
echo -e "${GREEN}✨ ¡Disfruta tu escritorio remoto VNC!${NC}"

# =============================================================================
# OPCIONAL: CREAR SERVICIO SYSTEMD
# =============================================================================

read -p "¿Quieres crear un servicio systemd para auto-iniciar VNC? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    print_info "Creando servicio systemd..."
    
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
ExecStart=/usr/bin/vncserver -depth 24 -geometry 1920x1080 -localhost no :%i
ExecStop=/usr/bin/vncserver -kill :%i

[Install]
WantedBy=multi-user.target
EOF

    sudo systemctl daemon-reload
    sudo systemctl enable vncserver@1.service
    
    print_status "Servicio systemd creado. VNC se iniciará automáticamente al reiniciar"
fi

echo ""
print_status "Script completado. ¡Todo listo para usar VNC!"
