#!/bin/bash

# Script de despliegue para AWS EC2
# Ejecutar con: bash deploy_aws.sh

set -e  # Detener en caso de error

echo "🚀 Iniciando despliegue del Monitor SAT Backend en AWS..."

# Variables de configuración
PROJECT_NAME="monitor-sat"
EC2_USER="ubuntu"
EC2_HOST="tu-instancia-ec2.amazonaws.com"  # Reemplazar con tu IP/hostname
KEY_PATH="~/.ssh/tu-clave-aws.pem"  # Reemplazar con tu clave SSH
REMOTE_DIR="/home/ubuntu/monitor-sat"

# Colores para output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}📦 Preparando archivos para despliegue...${NC}"

# Crear archivo .env para producción
cat > .env << EOL
DEBUG=False
FINKOK_USERNAME=tu_usuario_finkok
FINKOK_PASSWORD=tu_password_finkok
CERT_PATH=/home/ubuntu/monitor-sat/certificados/cert.cer
KEY_PATH=/home/ubuntu/monitor-sat/certificados/key.key
PORT=5000
EOL

echo -e "${GREEN}✓ Archivo .env creado${NC}"

# Crear archivo de configuración nginx
cat > nginx.conf << EOL
server {
    listen 80;
    server_name tu-dominio.com;  # Reemplazar con tu dominio
    
    location / {
        return 301 https://\$server_name\$request_uri;
    }
}

server {
    listen 443 ssl;
    server_name tu-dominio.com;  # Reemplazar con tu dominio
    
    ssl_certificate /path/to/ssl/cert.pem;
    ssl_certificate_key /path/to/ssl/private.key;
    
    location / {
        proxy_pass http://127.0.0.1:5000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOL

echo -e "${GREEN}✓ Configuración nginx creada${NC}"

# Crear script de instalación para el servidor
cat > install_server.sh << EOL
#!/bin/bash

echo "🔧 Configurando servidor Ubuntu..."

# Actualizar sistema
sudo apt update && sudo apt upgrade -y

# Instalar Python 3.9, pip y dependencias
sudo apt install -y python3.9 python3.9-pip python3.9-venv nginx certbot python3-certbot-nginx

# Crear directorio del proyecto
mkdir -p $REMOTE_DIR
cd $REMOTE_DIR

# Crear entorno virtual
python3.9 -m venv venv
source venv/bin/activate

# Instalar dependencias
pip install -r requirements.txt

# Crear directorio para certificados
mkdir -p certificados

# Configurar nginx
sudo cp nginx.conf /etc/nginx/sites-available/monitor-sat
sudo ln -sf /etc/nginx/sites-available/monitor-sat /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default

# Crear servicio systemd
sudo tee /etc/systemd/system/monitor-sat.service > /dev/null << EOF
[Unit]
Description=Monitor SAT Backend
After=network.target

[Service]
User=ubuntu
Group=ubuntu
WorkingDirectory=$REMOTE_DIR
Environment=PATH=$REMOTE_DIR/venv/bin
ExecStart=$REMOTE_DIR/venv/bin/gunicorn --bind 127.0.0.1:5000 --workers 4 app:app
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# Habilitar y iniciar servicios
sudo systemctl daemon-reload
sudo systemctl enable monitor-sat
sudo systemctl start monitor-sat
sudo systemctl enable nginx
sudo systemctl restart nginx

echo "✅ Servidor configurado correctamente"
EOL

chmod +x install_server.sh

echo -e "${YELLOW}📤 Subiendo archivos al servidor...${NC}"

# Subir archivos al servidor
scp -i $KEY_PATH -r . $EC2_USER@$EC2_HOST:$REMOTE_DIR/

echo -e "${YELLOW}🔧 Ejecutando instalación en el servidor...${NC}"

# Ejecutar script de instalación en el servidor
ssh -i $KEY_PATH $EC2_USER@$EC2_HOST "cd $REMOTE_DIR && bash install_server.sh"

echo -e "${GREEN}✅ ¡Despliegue completado!${NC}"
echo -e "${YELLOW}📝 Próximos pasos:${NC}"
echo "1. Sube tus certificados SAT a la carpeta 'certificados/' en el servidor"
echo "2. Configura las variables de entorno en el archivo .env"
echo "3. Obtén un certificado SSL con: sudo certbot --nginx -d tu-dominio.com"
echo "4. Reinicia el servicio: sudo systemctl restart monitor-sat"

echo -e "${GREEN}🌐 Tu backend estará disponible en: https://tu-dominio.com${NC}"
