# Variables de configuración

variable "aws_region" {
  description = "Región de AWS donde desplegar"
  type        = string
  default     = "us-east-2"
}

variable "project_name" {
  description = "Nombre del proyecto"
  type        = string
  default     = "monitor-sat"
}

variable "instance_type" {
  description = "Tipo de instancia EC2"
  type        = string
  default     = "t3.micro"

  validation {
    condition     = contains(["t3.micro", "t3.small", "t3.medium", "t2.micro", "t2.small"], var.instance_type)
    error_message = "El tipo de instancia debe ser t3.micro, t3.small, t3.medium, t2.micro, o t2.small para mantener costos bajos."
  }
}

variable "volume_size" {
  description = "Tamaño del volumen EBS en GB"
  type        = number
  default     = 20

  validation {
    condition     = var.volume_size >= 8 && var.volume_size <= 100
    error_message = "El tamaño del volumen debe estar entre 8 y 100 GB."
  }
}

variable "public_key" {
  description = "Clave pública SSH para acceso a la instancia"
  type        = string
}

variable "domain_name" {
  description = "Nombre del dominio para la aplicación"
  type        = string
}

variable "admin_email" {
  description = "Email del administrador para certificados SSL"
  type        = string
}

variable "finkok_username" {
  description = "Usuario de Finkok"
  type        = string
  sensitive   = true
}

variable "finkok_password" {
  description = "Contraseña de Finkok"
  type        = string
  sensitive   = true
}

variable "cert_content" {
  description = "Contenido del certificado SAT (base64)"
  type        = string
  sensitive   = true
}

variable "key_content" {
  description = "Contenido de la llave privada SAT (base64)"
  type        = string
  sensitive   = true
}

variable "github_repo" {
  description = "Repositorio de GitHub con el código"
  type        = string
  default     = ""
}

variable "github_branch" {
  description = "Rama del repositorio a usar"
  type        = string
  default     = "main"
}

variable "create_route53_zone" {
  description = "Crear zona Route53 para el dominio"
  type        = bool
  default     = false
}

variable "environment" {
  description = "Ambiente de despliegue"
  type        = string
  default     = "production"

  validation {
    condition     = contains(["development", "staging", "production"], var.environment)
    error_message = "El ambiente debe ser development, staging, o production."
  }
}