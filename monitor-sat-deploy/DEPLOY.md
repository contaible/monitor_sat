# 🚀 Despliegue con Terraform - Monitor SAT Backend

Esta configuración de Terraform despliega automáticamente tu Monitor SAT Backend en AWS con las siguientes características:

## ✨ Características

- **💰 Costo optimizado**: Usa t3.micro (Free Tier elegible) ~$8/mes
- **🔒 Seguridad**: SSL automático, Secrets Manager, IAM roles
- **⚡ Auto-configuración**: Nginx, systemd, firewall, fail2ban
- **📊 Monitoreo**: CloudWatch logs integrado
- **🔄 Escalable**: Fácil upgrade a instancias más grandes

## 📋 Prerrequisitos

### 1. Instalar Terraform
```bash
# Ubuntu/Debian
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
sudo apt-get update && sudo apt-get install terraform

# macOS
brew install terraform

# Verificar instalación
terraform version
```

### 2. Configurar AWS CLI
```bash
# Instalar AWS CLI
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Configurar credenciales
aws configure
# AWS Access Key ID: tu-access-key
# AWS Secret Access Key: tu-secret-key
# Default region: us-east-2
# Default output format: json
```

### 3. Generar clave SSH
```bash
ssh-keygen -t rsa -b 4096 -f ~/.ssh/monitor-sat
# Usar la clave pública en terraform.tfvars
cat ~/.ssh/monitor-sat.pub
```

### 4. Preparar certificados SAT
```bash
# Convertir certificados a base64
base64 -w 0 cert.cer > cert_base64.txt
base64 -w 0 key.key > key_base64.txt
```

## 🚀 Despliegue Paso a Paso

### Paso 1: Preparar archivos
```bash
# Crear directorio del proyecto
mkdir monitor-sat-terraform
cd monitor-sat-terraform

# Copiar archivos de Terraform (main.tf, variables.tf, etc.)
# Crear terraform.tfvars basado en el ejemplo
cp terraform.tfvars.example terraform.tfvars
```

### Paso 2: Configurar variables
Edita `terraform.tfvars` con tus valores:

```hcl
# Configuración mínima requerida
aws_region      = "us-east-2"
project_name    = "monitor-sat"
instance_type   = "t3.micro"
public_key      = "ssh-rsa AAAAB3NzaC1yc2EAAAA... tu-clave-ssh"
domain_name     = "api.tu-dominio.com"
admin_email     = "admin@tu-dominio.com"
finkok_username = "tu_usuario_finkok"
finkok_password = "tu_password_finkok"
cert_content    = "contenido-base64-cert"
key_content     = "contenido-base64-key"
```

### Paso 3: Inicializar Terraform
```bash
terraform init
```

### Paso 4: Planificar despliegue
```bash
terraform plan
```

### Paso 5: Aplicar configuración
```bash
terraform apply
# Escribe 'yes' para confirmar
```

### Paso 6: Configurar DNS
Apunta tu dominio a la IP que aparece en los outputs:
```bash
# Obtener IP pública
terraform output public_ip
```

## 📊 Estimación de Costos

### Configuración Mínima (t3.micro)
| Recurso | Costo Mensual | Detalles |
|---------|---------------|----------|
| EC2 t3.micro | $8.50 | 750 horas free tier |
| EBS gp3 20GB | $1.60 | $0.08/GB/mes |
| Elastic IP | $3.65 | Solo cuando no está asignada |
| Secrets Manager | $0.40 | $0.40/secret/mes |
| CloudWatch Logs | $0.50 | 5GB incluidos |
| **Total** | **~$14/mes** | **$0 primer año con Free Tier** |

### Configuración Recomendada (t3.small)
| Recurso | Costo Mensual | Detalles |
|---------|---------------|----------|
| EC2 t3.small | $15.18 | Mejor performance |
| EBS gp3 20GB | $1.60 | $0.08/GB/mes |
| Elastic IP | $3.65 | IP estática |
| Secrets Manager | $0.40 | Credenciales seguras |
| CloudWatch Logs | $0.50 | Monitoreo |
| **Total** | **~$21/mes** | **Producción recomendada** |

## 🔧 Comandos Útiles

### Conectarse al servidor
```bash
# Usando output de Terraform
$(terraform output -raw ssh_command)

# O manualmente
ssh -i ~/.ssh/monitor-sat ubuntu@$(terraform output -raw public_ip)
```

### Verificar estado de servicios
```bash
# En el servidor
sudo systemctl status monitor-sat
sudo systemctl status nginx
sudo journalctl -u monitor-sat -f
```

### Actualizar aplicación
```bash
# En el servidor
cd /home/monitor-sat/app
sudo -u monitor-sat git pull
sudo systemctl restart monitor-sat
```

### Ver logs
```bash
# Logs de la aplicación
sudo journalctl -u monitor-sat -f

# Logs de Nginx
sudo tail -f /var/log/nginx/access.log
sudo tail -f /var/log/nginx/error.log

# Logs de CloudWatch
aws logs tail /aws/ec2/monitor-sat --follow
```

## 🔒 Gestión de Secretos

Los secretos se almacenan de forma segura en AWS Secrets Manager:

```bash
# Ver secretos (requiere permisos)
aws secretsmanager get-secret-value \
  --secret-id monitor-sat/credentials \
  --query SecretString \
  --output text | jq

# Actualizar secretos
aws secretsmanager update-secret \
  --secret-id monitor-sat/credentials \
  --secret-string '{"finkok_username":"nuevo_usuario"}'
```

## 📈 Escalabilidad

### Upgrade de instancia
```hcl
# En terraform.tfvars
instance_type = "t3.small"  # o "t3.medium"
```

```bash
terraform apply
```

### Agregar Load Balancer (para múltiples instancias)
```hcl
# Agregar en main.tf
resource "aws_lb" "main" {
  name               = "${var.project_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.monitor_sat.id]
  subnets           = [aws_subnet.public.id, aws_subnet.public_2.id]
}
```

## 🛠️ Solución de Problemas

### Error: "InvalidKeyPair.NotFound"
```bash
# Verificar que la clave SSH esté configurada correctamente
aws ec2 describe-key-pairs --key-names monitor-sat-key
```

### Error: "Certificate validation failed"
```bash
# Verificar que el dominio apunte a la IP correcta
dig +short tu-dominio.com
```

### Error: "Service failed to start"
```bash
# Conectarse al servidor y verificar logs
ssh -i ~/.ssh/monitor-sat ubuntu@IP_PUBLICA
sudo journalctl -u monitor-sat --no-pager
```

### Error: "Secrets Manager access denied"
```bash
# Verificar que el rol IAM tenga permisos
aws iam get-role-policy --role-name monitor-sat-ec2-role --policy-name monitor-sat-secrets-policy
```

## 🔄 Actualización y Mantenimiento

### Actualizar certificados SSL
```bash
# Los certificados se renuevan automáticamente
# Para forzar renovación:
sudo certbot renew --force-renewal
```

### Backup de datos
```bash
# Crear snapshot del volumen
aws ec2 create-snapshot \
  --volume-id $(terraform output -raw volume_id) \
  --description "Monitor SAT backup $(date)"
```

### Restaurar desde backup
```bash
# En caso de problemas, puedes recrear desde snapshot
terraform destroy
# Modificar main.tf para usar snapshot_id
terraform apply
```

## 🚨 Seguridad

### Configuración incluida
- ✅ SSL/TLS automático con Let's Encrypt
- ✅ Firewall configurado (ufw)
- ✅ Fail2ban para protección SSH
- ✅ Security Groups restrictivos
- ✅ Secrets Manager para credenciales
- ✅ IAM roles con permisos mínimos
- ✅ Volúmenes EBS encriptados

### Recomendaciones adicionales
```bash
# Configurar 2FA para AWS
aws iam enable-mfa-device

# Rotar credenciales regularmente
aws iam update-access-key

# Monitorear accesos
aws cloudtrail lookup-events
```

## 📞 Soporte

### Logs importantes
- `/var/log/user-data.log` - Inicialización del servidor
- `/var/log/nginx/` - Logs de Nginx
- `journalctl -u monitor-sat` - Logs de la aplicación
- CloudWatch `/aws/ec2/monitor-sat` - Logs centralizados

### Comandos de diagnóstico
```bash
# Health check
curl https://tu-dominio.com/

# Estado del sistema
/home/monitor-sat/check_status.sh

# Uso de recursos
htop
df -h
free -h
```

---

## 🎯 Próximos Pasos

1. ✅ **Despliegue básico funcionando**
2. 🔄 **Configurar monitoreo avanzado** (CloudWatch Dashboard)
3. 📱 **Implementar notificaciones** (SNS/SES)
4. 🔄 **Auto Scaling** (ASG + ALB)
5. 🌍 **Multi-región** (Disaster Recovery)
6. 📊 **Métricas personalizadas** (Prometheus/Grafana)

¡Tu Monitor SAT Backend está listo para producción! 🎉