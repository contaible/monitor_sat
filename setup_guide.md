# 🚀 Monitor SAT Backend - Guía Completa de Instalación

## 📋 Prerrequisitos

### 1. Certificados SAT
- **e.firma (FIEL)**: Descarga tu certificado desde el portal del SAT
- **Archivos necesarios**:
  - `cert.cer` (certificado público)
  - `key.key` (llave privada)

### 2. Cuenta en Finkok
- Regístrate en [finkok.com](https://finkok.com)
- Obtén tu usuario y contraseña de API
- Configura tu RFC y certificados en la plataforma

### 3. Servidor AWS EC2
- **Instancia recomendada**: t3.micro o superior
- **Sistema operativo**: Ubuntu 20.04 LTS
- **Puertos abiertos**: 22 (SSH), 80 (HTTP), 443 (HTTPS)

## 🛠️ Instalación Local (Desarrollo)

### Paso 1: Clonar el Proyecto
```bash
git clone <tu-repositorio>
cd monitor_sat
```

### Paso 2: Crear Entorno Virtual
```bash
python3.9 -m venv venv
source venv/bin/activate  # Linux/Mac
# venv\Scripts\activate  # Windows
```

### Paso 3: Instalar Dependencias
```bash
pip install -r requirements.txt
```

### Paso 4: Configurar Certificados
```bash
mkdir certificados
# Copia tus archivos cert.cer y key.key a la carpeta certificados/
```

### Paso 5: Configurar Variables de Entorno
```bash
# Crear archivo .env
echo "DEBUG=True" > .env
echo "FINKOK_USERNAME=tu_usuario" >> .env
echo "FINKOK_PASSWORD=tu_password" >> .env
echo "CERT_PATH=certificados/cert.cer" >> .env
echo "KEY_PATH=certificados/key.key" >> .env
```

### Paso 6: Ejecutar la Aplicación
```bash
python app.py
```

### Paso 7: Probar la Aplicación
```bash
python test_backend.py
```

## 🌐 Despliegue en AWS

### Opción A: Despliegue Automático
```bash
# Editar variables en deploy_aws.sh
EC2_HOST="tu-ip-ec2.amazonaws.com"
KEY_PATH="~/.ssh/tu-clave.pem"

# Ejecutar despliegue
bash deploy_aws.sh
```

### Opción B: Despliegue Manual

#### 1. Conectar al Servidor
```bash
ssh -i ~/.ssh/tu-clave.pem ubuntu@tu-ip-ec2
```

#### 2. Actualizar Sistema
```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y python3.9 python3.9-pip python3.9-venv nginx
```

#### 3. Configurar Proyecto
```bash
mkdir -p ~/monitor-sat
cd ~/monitor-sat

# Subir archivos (desde tu máquina local)
scp -i ~/.ssh/tu-clave.pem -r . ubuntu@tu-ip-ec2:~/monitor-sat/
```

#### 4. Configurar Entorno Virtual
```bash
python3.9 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

#### 5. Configurar Systemd Service
```bash
sudo nano /etc/systemd/system/monitor-sat.service
```

```ini
[Unit]
Description=Monitor SAT Backend
After=network.target

[Service]
User=ubuntu
Group=ubuntu
WorkingDirectory=/home/ubuntu/monitor-sat
Environment=PATH=/home/ubuntu/monitor-sat/venv/bin
ExecStart=/home/ubuntu/monitor-sat/venv/bin/gunicorn --bind 127.0.0.1:5000 --workers 4 app:app
Restart=always

[Install]
WantedBy=multi-user.target
```

#### 6. Configurar Nginx
```bash
sudo nano /etc/nginx/sites-available/monitor-sat
```

```nginx
server {
    listen 80;
    server_name tu-dominio.com;
    
    location / {
        return 301 https://$server_name$request_uri;
    }
}

server {
    listen 443 ssl;
    server_name tu-dominio.com;
    
    ssl_certificate /etc/letsencrypt/live/tu-dominio.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/tu-dominio.com/privkey.pem;
    
    location / {
        proxy_pass http://127.0.0.1:5000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

#### 7. Habilitar Servicios
```bash
sudo ln -s /etc/nginx/sites-available/monitor-sat /etc/nginx/sites-enabled/
sudo rm /etc/nginx/sites-enabled/default

sudo systemctl daemon-reload
sudo systemctl enable monitor-sat
sudo systemctl start monitor-sat
sudo systemctl enable nginx
sudo systemctl restart nginx
```

#### 8. Configurar SSL con Let's Encrypt
```bash
sudo apt install certbot python3-certbot-nginx
sudo certbot --nginx -d tu-dominio.com
```

## 🔧 Configuración de AWS Secrets Manager (Recomendado)

### 1. Crear Secret en AWS
```bash
aws secretsmanager create-secret \
    --name "monitor-sat/credentials" \
    --description "Credenciales para Monitor SAT" \
    --secret-string '{
        "finkok_username":"tu_usuario",
        "finkok_password":"tu_password",
        "cert_content":"contenido_base64_cert",
        "key_content":"contenido_base64_key"
    }'
```

### 2. Modificar app.py para usar Secrets Manager
```python
import boto3
import json

def get_secret():
    secret_name = "monitor-sat/credentials"
    region_name = "us-west-2"  # Tu región
    
    session = boto3.session.Session()
    client = session.client(
        service_name='secretsmanager',
        region_name=region_name
    )
    
    try:
        get_secret_value_response = client.get_secret_value(
            SecretId=secret_name
        )
        return json.loads(get_secret_value_response['SecretString'])
    except Exception as e:
        logger.error(f"Error obteniendo secretos: {e}")
        return None
```

## 📊 Monitoreo y Logs

### 1. Ver Logs del Servicio
```bash
sudo journalctl -u monitor-sat -f
```

### 2. Ver Logs de Nginx
```bash
sudo tail -f /var/log/nginx/access.log
sudo tail -f /var/log/nginx/error.log
```

### 3. Monitorear Estado del Servicio
```bash
sudo systemctl status monitor-sat
sudo systemctl status nginx
```

### 4. Configurar Logrotate
```bash
sudo nano /etc/logrotate.d/monitor-sat
```

```
/home/ubuntu/monitor-sat/logs/*.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    notifempty
    create 644 ubuntu ubuntu
    postrotate
        sudo systemctl reload monitor-sat
    endscript
}
```

## 🧪 Pruebas y Validación

### 1. Pruebas Locales
```bash
# Ejecutar suite de pruebas
python test_backend.py

# Prueba manual con curl
curl -X POST http://localhost:5000/consultar_sat \
  -H "Content-Type: application/json" \
  -d '{"rfc": "XEXX010101XXX"}'
```

### 2. Pruebas en Producción
```bash
# Health check
curl https://tu-dominio.com/

# Consulta SAT
curl -X POST https://tu-dominio.com/consultar_sat \
  -H "Content-Type: application/json" \
  -d '{"rfc": "TU_RFC_REAL"}'
```

## 🔒 Seguridad

### 1. Firewall
```bash
sudo ufw allow 22
sudo ufw allow 80
sudo ufw allow 443
sudo ufw enable
```

### 2. Fail2ban
```bash
sudo apt install fail2ban
sudo systemctl enable fail2ban
sudo systemctl start fail2ban
```

### 3. Actualizar Sistema Regularmente
```bash
# Agregar a crontab
sudo crontab -e

# Actualización automática semanal
0 2 * * 0 apt update && apt upgrade -y
```

## 🚨 Solución de Problemas

### Error: "Certificados no encontrados"
```bash
# Verificar archivos
ls -la certificados/
# Verificar permisos
chmod 600 certificados/*.key
chmod 644 certificados/*.cer
```

### Error: "Conexión rechazada a Finkok"
```bash
# Verificar configuración de red
curl -I https://api.finkok.com
# Verificar variables de entorno
echo $FINKOK_USERNAME
```

### Error: "Servicio no inicia"
```bash
# Verificar logs
sudo journalctl -u monitor-sat --no-pager
# Verificar puerto
sudo netstat -tulnp | grep :5000
```

### Error: "SSL Certificate"
```bash
# Renovar certificado
sudo certbot renew --dry-run
# Verificar configuración nginx
sudo nginx -t
```

## 📈 Optimización para Producción

### 1. Configurar Cache
```python
from flask_caching import Cache

cache = Cache(app, config={'CACHE_TYPE': 'simple'})

@cache.cached(timeout=300)  # 5 minutos
def consultar_sat_cached(rfc):
    # Tu lógica aquí
    pass
```

### 2. Rate Limiting
```python
from flask_limiter import Limiter
from flask_limiter.util import get_remote_address

limiter = Limiter(
    app,
    key_func=get_remote_address,
    default_limits=["100 per hour"]
)

@app.route('/consultar_sat', methods=['POST'])
@limiter.limit("10 per minute")
def consultar_sat():
    # Tu código aquí
    pass
```

### 3. Base de Datos (Opcional)
```bash
# Instalar PostgreSQL
sudo apt install postgresql postgresql-contrib
sudo -u postgres createuser --interactive
sudo -u postgres createdb monitor_sat
```

## 📞 Soporte y Contacto

- **Documentación**: [Enlace a tu documentación]
- **Issues**: [Enlace a tu repositorio de issues]
- **Email**: soporte@tu-empresa.com

---

## 🎯 Próximos Pasos

1. ✅ Backend funcionando
2. 🔄 Crear frontend (dashboard web)
3. 📱 Desarrollar app móvil
4. 📊 Implementar analytics
5. 🔔 Sistema de notificaciones
6. 🤖 Integración con bots (Telegram/WhatsApp)

---

**¡Tu Monitor SAT Backend está listo para producción!** 🎉