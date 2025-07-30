############################################
# Cost Optimization — Presupuesto Mensual  #
############################################

# Presupuesto mensual simple SIN cost_filters/cost_filter ni cost_types no soportados.
# Si no quieres budgets en DEV, comenta todo este recurso.
resource "aws_budgets_budget" "monitor_sat_budget" {
  name        = "monitor-sat-monthly"
  budget_type = "COST"
  time_unit   = "MONTHLY"

  # Límite de presupuesto (USD)
  limit_amount = "10"
  limit_unit   = "USD"

  # Notificación al 80% del presupuesto
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.budget_alert_email]
  }
}

#########################
# Variables de soporte  #
#########################

# Si ya la definiste en otro archivo, puedes borrar esta variable aquí.
variable "budget_alert_email" {
  type        = string
  description = "Correo para recibir alertas del presupuesto de AWS"
  default     = "tu-correo@dominio.com"
}

############################################
# Salida informativa de costos estimados   #
############################################

output "cost_optimization_info" {
  description = "Resumen estimado de costos y configuración de la instancia"
  value = {
    budget_name   = aws_budgets_budget.monitor_sat_budget.name
    monthly_limit = "$10 USD"
    instance_type = var.instance_type
    # Construimos la cadena con format() y una condición fuera de la cadena
    estimated_monthly = format(
      "%s + storage + otros",
      (
        var.instance_type == "t3.nano" ? "$4.25" :
        var.instance_type == "t3.micro" ? "$8.50" :
        var.instance_type == "t3.small" ? "$17.00" : "$?"
      )
    )
  }
}
