# --- CloudWatch Dashboard para Monitoramento da Aplicação ---

resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.project_name}-dashboard-${var.environment}"

  dashboard_body = jsonencode({
    widgets = [
      # --- Widget de Cabeçalho ---
      {
        type   = "text",
        width  = 24,
        height = 1,
        properties = {
          markdown = "## Dashboard de Monitoramento: ${var.project_name} (${var.environment})"
        }
      },
      # --- Métricas do Application Load Balancer ---
      {
        type   = "metric",
        width  = 12,
        height = 6,
        properties = {
          metrics = [
            ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", aws_alb.main.name, { "label" = "Total de Requisições" }],
            [".", "HTTPCode_Target_5XX_Count", ".", ".", { "label" = "Erros 5xx do Target" }],
            [".", "HTTPCode_Target_4XX_Count", ".", ".", { "label" = "Erros 4xx do Target" }]
          ],
          view    = "timeSeries",
          stacked = false,
          region  = var.aws_region,
          title   = "ALB: Requisições e Erros"
        }
      },
      {
        type   = "metric",
        width  = 12,
        height = 6,
        properties = {
          metrics = [
            ["AWS/ApplicationELB", "TargetConnectionErrorCount", "LoadBalancer", aws_alb.main.name, { "label" = "Erros de Conexão com Target" }],
            [".", "HealthyHostCount", "TargetGroup", aws_lb_target_group.nginx.name, { "label" = "Hosts Saudáveis (Nginx)" }],
            [".", "UnHealthyHostCount", ".", ".", { "label" = "Hosts Não Saudáveis (Nginx)" }]
          ],
          view    = "timeSeries",
          stacked = false,
          region  = var.aws_region,
          title   = "ALB: Saúde do Target Group (Nginx)"
        }
      },
      # --- Métricas do ECS Service (Nginx) ---
      {
        type   = "metric",
        width  = 12,
        height = 6,
        properties = {
          metrics = [
            ["AWS/ECS", "CPUUtilization", "ClusterName", aws_ecs_cluster.main.name, "ServiceName", aws_ecs_service.nginx.name, { "label" = "Uso de CPU (%)" }],
            [".", "MemoryUtilization", ".", ".", ".", ".", { "label" = "Uso de Memória (%)" }]
          ],
          view    = "timeSeries",
          stacked = false,
          region  = var.aws_region,
          title   = "ECS Service: Nginx Gateway"
        }
      },
      # --- Métricas do ECS Service (API) ---
      {
        type   = "metric",
        width  = 12,
        height = 6,
        properties = {
          metrics = [
            ["AWS/ECS", "CPUUtilization", "ClusterName", aws_ecs_cluster.main.name, "ServiceName", aws_ecs_service.api.name, { "label" = "Uso de CPU (%)" }],
            [".", "MemoryUtilization", ".", ".", ".", ".", { "label" = "Uso de Memória (%)" }]
          ],
          view    = "timeSeries",
          stacked = false,
          region  = var.aws_region,
          title   = "ECS Service: API Python"
        }
      },
      # --- Métricas do WAF ---
      {
        type   = "metric",
        width  = 12,
        height = 6,
        properties = {
          metrics = [
            ["AWS/WAFV2", "BlockedRequests", "Region", var.aws_region, "WebACL", aws_wafv2_web_acl.main.name, "Rule", "ALL", { "label" = "Total de Requisições Bloqueadas" }],
            [".", "AllowedRequests", ".", ".", ".", ".", ".", ".", { "label" = "Total de Requisições Permitidas" }]
          ],
          view    = "timeSeries",
          stacked = false,
          region  = var.aws_region,
          title   = "WAF: Requisições Bloqueadas vs Permitidas"
        }
      }
    ]
  })
}
