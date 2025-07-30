# Makefile para facilitar el despliegue de Monitor SAT

.PHONY: help init plan apply destroy ssh logs status clean validate fmt

# Variables
PROJECT_NAME ?= monitor-sat
AWS_REGION ?= us-east-2

# Colors for output
RED    := \033[31m
GREEN  := \033[32m
YELLOW := \033[33m
BLUE   := \033[34m
RESET  := \033[0m

help: ## Mostrar esta ayuda
	@echo "$(BLUE)Monitor SAT - Terraform Management$(RESET)"
	@echo ""
	@echo "$(YELLOW)Comandos disponibles:$(RESET)"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  $(GREEN)%-15s$(RESET) %s\n", $$1, $$2}' $(MAKEFILE_LIST)

init: ## Inicializar Terraform
	@echo "$(BLUE)Inicializando Terraform...$(RESET)"
	terraform init
	@echo "$(GREEN)✓ Terraform inicializado$(RESET)"

validate: ## Validar configuración de Terraform
	@echo "$(BLUE)Validando configuración...$(RESET)"
	terraform validate
	terraform fmt -check=true
	@echo "$(GREEN)✓ Configuración válida$(RESET)"

fmt: ## Formatear archivos de Terraform
	@echo "$(BLUE)Formateando archivos...$(RESET)"
	terraform fmt -recursive
	@echo "$(GREEN)✓ Archivos formateados$(RESET)"

plan: ## Planificar cambios
	@echo "$(BLUE)Planificando despliegue...$(RESET)"
	terraform plan -out=tfplan
	@echo "$(YELLOW)Revisa el plan antes de aplicar$(RESET)"

apply: ## Aplicar cambios
	@echo "$(BLUE)Aplicando configuración...$(RESET)"
	@if [ -f tfplan ]; then \
		terraform apply tfplan; \
		rm tfplan; \
	else \
		terraform apply; \
	fi
	@echo "$(GREEN)✓ Despliegue completado$(RESET)"
	@make show-info

deploy: init validate plan apply ## Despliegue completo (init + validate + plan + apply)

show-info: ## Mostrar información del despliegue
	@echo ""
	@echo "$(GREEN)🎉 Despliegue completado exitosamente!$(RESET)"
	@echo ""
	@echo "$(YELLOW)📋 Información del servidor:$(RESET)"
	@echo "  IP Pública: $(shell terraform output -raw public_ip 2>/dev/null || echo 'No disponible')"
	@echo "  Dominio: $(shell terraform output -raw domain_name 2>/dev/null || echo 'No configurado')"
	@echo "  URL: $(shell terraform output -raw application_url 2>/dev/null || echo 'No disponible')"
	@echo ""
	@echo "$(YELLOW)🔐 Conexión SSH:$(RESET)"
	@echo "  $(shell terraform output -raw ssh_command 2>/dev/null || echo 'SSH no disponible')"
	@echo ""
	@echo "$(YELLOW)📊 Health Check:$(RESET)"
	@echo "  $(shell terraform output -raw health_check_url 2>/dev/null || echo 'Health check no disponible')"

ssh: ## Conectarse al servidor via SSH
	@echo "$(BLUE)Conectando al servidor...$(RESET)"
	@eval "$$(terraform output -raw ssh_command 2>/dev/null)" || echo "$(RED)Error: No se puede conectar$(RESET)"

status: ## Verificar estado de servicios
	@echo "$(BLUE)Verificando estado de servicios...$(RESET)"
	@eval "$$(terraform output -raw ssh_command 2>/dev/null) 'sudo /home/monitor-sat/check_status.sh'" || echo "$(RED)Error: No se puede verificar estado$(RESET)"

logs: ## Ver logs de la aplicación
	@echo "$(BLUE)Mostrando logs de la aplicación...$(RESET)"
	@eval "$$(terraform output -raw ssh_command 2>/dev/null) 'sudo journalctl -u monitor-sat -f'" || echo "$(RED)Error: No se pueden mostrar logs$(RESET)"

test: ## Probar la aplicación
	@echo "$(BLUE)Probando aplicación...$(RESET)"
	@HEALTH_URL=$$(terraform output -raw health_check_url 2>/dev/null); \
	if [ "$$HEALTH_URL" != "" ]; then \
		curl -s $$HEALTH_URL | jq . || echo "$(RED)Error en health check$(RESET)"; \
	else \
		echo "$(RED)URL no disponible$(RESET)"; \
	fi

update: ## Actualizar aplicación en el servidor
	@echo "$(BLUE)Actualizando aplicación...$(RESET)"
	@eval "$$(terraform output -raw ssh_command 2>/dev/null) 'cd /home/monitor-sat/app && sudo -u monitor-sat git pull && sudo systemctl restart monitor-sat'" || echo "$(RED)Error: No se puede actualizar$(RESET)"

backup: ## Crear backup del volumen
	@echo "$(BLUE)Creando backup...$(RESET)"
	@INSTANCE_ID=$$(terraform output -raw instance_id 2>/dev/null); \
	if [ "$$INSTANCE_ID" != "" ]; then \
		aws ec2 create-snapshot \
			--volume-id $$(aws ec2 describe-instances --instance-ids $$INSTANCE_ID --query 'Reservations[0].Instances[0].BlockDeviceMappings[0].Ebs.VolumeId' --output text) \
			--description "Monitor SAT backup $$(date +%Y%m%d_%H%M%S)" \
			--region $(AWS_REGION); \
		echo "$(GREEN)✓ Backup creado$(RESET)"; \
	else \
		echo "$(RED)Error: Instancia no encontrada$(RESET)"; \
	fi

clean: ## Limpiar archivos temporales
	@echo "$(BLUE)Limpiando archivos temporales...$(RESET)"
	rm -f tfplan
	rm -f terraform.tfstate.backup.*
	rm -f .terraform.lock.hcl.backup
	@echo "$(GREEN)✓ Archivos temporales eliminados$(RESET)"

destroy: ## Destruir infraestructura (¡CUIDADO!)
	@echo "$(RED)⚠️  ADVERTENCIA: Esto eliminará toda la infraestructura$(RESET)"
	@echo "$(YELLOW)¿Estás seguro? Escribe 'yes' para continuar:$(RESET)"
	@read confirm; \
	if [ "$$confirm" = "yes" ]; then \
		terraform destroy; \
		echo "$(GREEN)✓ Infraestructura eliminada$(RESET)"; \
	else \
		echo "$(YELLOW)Operación cancelada$(RESET)"; \
	fi

check-vars: ## Verificar variables requeridas
	@echo "$(BLUE)Verificando variables requeridas...$(RESET)"
	@if [ ! -f terraform.tfvars ]; then \
		echo "$(RED)Error: archivo terraform.tfvars no encontrado$(RESET)"; \
		echo "$(YELLOW)Copia terraform.tfvars.example y configura tus valores$(RESET)"; \
		exit 1; \
	fi
	@echo "$(GREEN)✓ Variables verificadas$(RESET)"

cost: ## Estimar costos (requiere infracost)
	@echo "$(BLUE)Estimando costos...$(RESET)"
	@if command -v infracost >/dev/null 2>&1; then \
		infracost breakdown --path .; \
	else \
		echo "$(YELLOW)infracost no instalado. Para instalar:$(RESET)"; \
		echo "curl -fsSL https://raw.githubusercontent.com/infracost/infracost/master/scripts/install.sh | sh"; \
	fi

docs: ## Generar documentación
	@echo "$(BLUE)Generando documentación...$(RESET)"
	@if command -v terraform-docs >/dev/null 2>&1; then \
		terraform-docs markdown table --output-file TERRAFORM-DOCS.md .; \
		echo "$(GREEN)✓ Documentación generada en TERRAFORM-DOCS.md$(RESET)"; \
	else \
		echo "$(YELLOW)terraform-docs no instalado. Para instalar:$(RESET)"; \
		echo "go install github.com/terraform-docs/terraform-docs@latest"; \
	fi

security: ## Análisis de seguridad (requiere tfsec)
	@echo "$(BLUE)Analizando seguridad...$(RESET)"
	@if command -v tfsec >/dev/null 2>&1; then \
		tfsec .; \
	else \
		echo "$(YELLOW)tfsec no instalado. Para instalar:$(RESET)"; \
		echo "curl -s https://raw.githubusercontent.com/aquasecurity/tfsec/master/scripts/install_linux.sh | bash"; \
	fi

# Comandos combinados
quick-deploy: check-vars init validate apply ## Despliegue rápido con validaciones

full-deploy: check-vars init validate fmt plan apply test ## Despliegue completo con todas las verificaciones

# Default target
.DEFAULT_GOAL := help