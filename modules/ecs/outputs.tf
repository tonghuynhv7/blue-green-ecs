output "cluster_name"  { value = aws_ecs_cluster.this.name }
output "cluster_arn"   { value = aws_ecs_cluster.this.arn }
output "service_name"  { value = aws_ecs_service.this.name }
output "task_def_arn"  { value = aws_ecs_task_definition.this.arn }
output "ecs_sg_id"     { value = aws_security_group.ecs_tasks.id }
output "log_group"     { value = aws_cloudwatch_log_group.this.name }
