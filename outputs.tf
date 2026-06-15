output "alb_dns_name" {
  description = "DNS của ALB — truy cập production qua port 80, staging qua port 81"
  value       = module.alb.alb_dns_name
}

output "ecr_repo_url" {
  description = "URL của ECR repo để push image"
  value       = module.ecr.repo_url
}

output "ecs_blue_cluster_name" {
  value = module.ecs_blue.cluster_name
}

output "ecs_green_cluster_name" {
  value = module.ecs_green.cluster_name
}

output "blue_service_name" {
  value = module.ecs_blue.service_name
}

output "green_service_name" {
  value = module.ecs_green.service_name
}

output "tg_blue_arn" {
  description = "ARN của Target Group Blue (dùng khi switch traffic)"
  value       = module.alb.tg_blue_arn
}

output "tg_green_arn" {
  description = "ARN của Target Group Green (dùng khi switch traffic)"
  value       = module.alb.tg_green_arn
}
