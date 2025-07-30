#!/bin/bash

# User Data Script para Monitor SAT Backend
# Este script se ejecuta automáticamente al iniciar la instancia EC2

set -e

# Variables pasadas desde Terraform
PROJECT_NAME="${project_name}"
AWS_REGION="${aws_region}"
SECRET_NAME="${secret_name}"
DOMAIN_NAME="${domain_name}"
ADMIN_EMAIL="${admin_email}"
GITHUB_REPO="${github_repo}"
GITHUB_BRANCH="${github_branch}"

# Configurar logging
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

echo "=== Iniciando configuración del servidor Monitor SAT ==="
echo "Timestamp: $(date)"
echo "Project: $PROJECT_NAME"
echo "Domain: $DOMAIN_NAME"

# Actualizar sistema
echo "Actualizando sistema..."
apt update && apt upgrade -y

# Instalar dependencias del sistema
echo "Instalando dependencias..."
apt install -y \
    python3.9 \
    python3.9-pip \
    python3.9-venv \
    python3.9-dev \
    nginx \
    certbot \
    python3-certbot-nginx \
    awscli \
    git \
    curl \
    unzip \
    htop \
    fail2ban \
    ufw \
    build-essential \
    libffi-dev \
    libssl-dev \
    pkg-config

# Configurar AWS CLI para la región
aws configure set default.region $AWS_REGION

# Crear usuario para la aplicación
if ! id "monitor-sat" >/dev/null 2>&1; then
    echo "Creando usuario monitor-sat..."
    useradd -m -s /bin/bash monitor-sat
    usermod -aG sudo monitor-sat
fi

# Crear directorio del proyecto
PROJECT_DIR="/home/monitor-sat/app"
mkdir -p $PROJECT_DIR
chown monitor-sat:monitor-sat $PROJECT_DIR

# Descargar código desde GitHub (si se especifica)
if [ ! -z "$GITHUB_REPO" ]; then
    echo "Clonando repositorio desde GitHub..."
    sudo -u monitor-sat git clone -b $GITHUB_BRANCH $GITHUB_REPO $PROJECT_DIR
else
    echo "Copiando código de ejemplo..."
    # Crear estructura básica si no hay repo
    sudo -u monitor-sat mkdir -p $PROJECT_DIR/{certificados,logs}
    
    # Crear requirements.txt
    cat > $PROJECT_DIR/requirements.txt << 'EOF'
Flask==2.3.3
Flask-CORS==4.0.0
requests==2.31.0
cryptography==41.0.7
gunicorn==21.2.0
python-dotenv==1.0.0
boto3==1.34.0
botocore==1.34.0
pyOpenSSL==23.3.0
lxml==4.9.3
Werkzeug==2.3.7
EOF

    # Crear app.py básico
    cat > $PROJECT_DIR/app.py << 'EOF'
from flask import Flask, request, jsonify
from flask_cors import CORS
import boto3
import json
import os
import logging
from datetime import datetime

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = Flask(__name__)
CORS(app)

def get_secrets():
    """Obtener secretos desde AWS Secrets Manager"""
    secret_name = os.getenv('SECRET_NAME')
    region_name = os.getenv('AWS_REGION', 'us-east-2')
    
    session = boto3.session.Session()
    client = session.client(
        service_name='secretsmanager',
        region_name=region_name
    )
    
    try:
        response = client.get_secret_value(SecretId=secret_name)
        return json.loads(response['SecretString'])
    except Exception as e:
        logger.error(f"Error obteniendo secretos: {e}")
        return {}

@app.route('/', methods=['GET'])
def health_check():
    return jsonify({
        "service": "Monitor SAT Backend",
        "status": "running",
        "version": "1.0.0",
        "timestamp": datetime.now().isoformat()
    })

@app.route('/consultar_sat', methods=['POST'])
def consultar_sat():
    if not request.json or 'rfc' not in request.json:
        return jsonify({'error': 'Se requiere RFC'}), 400
    
    rfc = request.json['rfc']
    
    return jsonify({
        "rfc": rfc,
        "timestamp": datetime.now().isoformat(),
        "status": "success",
        "message": "API funcionando correctamente"
    })

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
EOF

    chown -R monitor-sat:monitor-sat $PROJECT_DIR
fi

# Crear entorno virtual Python
echo "Configurando entorno virtual Python..."
sudo -u monitor-sat python3.9 -m venv $PROJECT_DIR/venv

# Activar entorno virtual e instalar dependencias
echo "Instalando dependencias Python..."
sudo -u monitor-sat bash -c "
    source $PROJECT_DIR/venv/bin/activate
    pip install --upgrade pip
    pip install -r $PROJECT_DIR/requirements.txt
"

# Crear archivo de configuración de entorno
echo "Configurando variables de entorno..."
cat > $PROJECT_DIR/.env << EOF
DEBUG=False
PORT=5000
SECRET_NAME=$SECRET_NAME
AWS_REGION=$AWS_REGION
ENVIRONMENT=production
EOF
chown monitor-sat:monitor-sat $PROJECT_DIR/.env
chmod 600 $PROJECT_DIR/.env

# Configurar Nginx
echo "Configurando Nginx..."
cat > /etc/nginx/sites-available/$PROJECT_NAME << EOF
server {
    listen 80;
    server_name $DOMAIN_NAME;
    
    # Redirect all HTTP to HTTPS
    return 301 https://\$server_name\$request_uri;
}

server {
    listen 443 ssl http2;
    server_name $DOMAIN_NAME;
    
    # SSL certificates (will be configured by certbot)
    ssl_certificate /etc/letsencrypt/live/$DOMAIN_NAME/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN_NAME/privkey.pem;
    
    # SSL configuration
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;
    ssl_session_timeout 10m;
    ssl_session_cache shared:SSL:10m;
    
    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    add_header Content-Security-Policy "default-src 'self' http: https: data: blob: 'unsafe-inline'" always;
    
    location / {
        proxy_pass http://127.0.0.1:5000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        
        # Timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
    
    # Health check endpoint
    location /health {
        access_log off;
        proxy_pass http://127.0.0.1:5000/;
    }
}
EOF

# Habilitar sitio Nginx
ln -sf /etc/nginx/sites-available/$PROJECT_NAME /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

# Verificar configuración de Nginx
nginx -t

# Crear servicio systemd
echo "Configurando servicio systemd..."
cat > /etc/systemd/system/$PROJECT_NAME.service << EOF
[Unit]
Description=Monitor SAT Backend
After=network.target

[Service]
Type=exec
User=monitor-sat
Group=monitor-sat
WorkingDirectory=$PROJECT_DIR
Environment=PATH=$PROJECT_DIR/venv/bin
EnvironmentFile=$PROJECT_DIR/.env
ExecStart=$PROJECT_DIR/venv/bin/gunicorn --bind 127.0.0.1:5000 --workers 2 --timeout 60 --access-logfile - --error-logfile - app:app
ExecReload=/bin/kill -s HUP \$MAINPID
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Habilitar y iniciar servicios
systemctl daemon-reload
systemctl enable $PROJECT_NAME
systemctl start $PROJECT_NAME

# Configurar firewall
echo "Configurando firewall..."
ufw --force enable
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp

# Configurar fail2ban
echo "Configurando fail2ban..."
systemctl enable fail2ban
systemctl start fail2ban

# Obtener certificado SSL
echo "Obteniendo certificado SSL..."
sleep 10 # Esperar a que nginx esté completamente inicializado

# Reiniciar nginx antes de obtener certificado
systemctl restart nginx
sleep 5

# Obtener certificado SSL con certbot
certbot --nginx -d $DOMAIN_NAME --non-interactive --agree-tos --email $ADMIN_EMAIL --redirect

# Configurar renovación automática
echo "0 12 * * * /usr/bin/certbot renew --quiet" | crontab -

# Reiniciar servicios
systemctl restart nginx
systemctl restart $PROJECT_NAME

# Configurar CloudWatch agent (opcional)
echo "Configurando CloudWatch logs..."
cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json << EOF
{
    "logs": {
        "logs_collected": {
            "files": {
                "collect_list": [
                    {
                        "file_path": "/var/log/user-data.log",
                        "log_group_name": "/aws/ec2/$PROJECT_NAME",
                        "log_stream_name": "{instance_id}/user-data"
                    },
                    {
                        "file_path": "/var/log/nginx/access.log",
                        "log_group_name": "/aws/ec2/$PROJECT_NAME",
                        "log_stream_name": "{instance_id}/nginx-access"
                    },
                    {
                        "file_path": "/var/log/nginx/error.log",
                        "log_group_name": "/aws/ec2/$PROJECT_NAME",
                        "log_stream_name": "{instance_id}/nginx-error"
                    }
                ]
            }
        }
    }
}
EOF

# Verificar estado de servicios
echo "=== Verificando estado de servicios ==="
systemctl status nginx --no-pager
systemctl status $PROJECT_NAME --no-pager

# Crear script de verificación
cat > /home/monitor-sat/check_status.sh << 'EOF'
#!/bin/bash
echo "=== Estado del servidor Monitor SAT ==="
echo "Fecha: $(date)"
echo ""
echo "=== Servicios ==="
systemctl status nginx --no-pager -l
echo ""
systemctl status monitor-sat --no-pager -l
echo ""
echo "=== Health Check ==="
curl -s http://localhost:5000/ | jq . || echo "Error en health check"
echo ""
echo "=== Logs recientes ==="
journalctl -u monitor-sat --no-pager -n 10
EOF

chmod +x /home/monitor-sat/check_status.sh
chown monitor-sat:monitor-sat /home/monitor-sat/check_status.sh

echo "=== Configuración completada exitosamente ==="
echo "Proyecto: $PROJECT_NAME"
echo "Dominio: $DOMAIN_NAME"
echo "Servidor listo para usar!"

# Ejecutar verificación final
sleep 10
sudo -u monitor-sat /home/monitor-sat/check_status.sh