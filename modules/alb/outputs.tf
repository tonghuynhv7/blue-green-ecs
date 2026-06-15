output "alb_dns_name"  { value = aws_lb.this.dns_name }
output "alb_arn"       { value = aws_lb.this.arn }
output "alb_sg_id"     { value = aws_security_group.alb.id }
output "tg_blue_arn"   { value = aws_lb_target_group.blue.arn }
output "tg_green_arn"  { value = aws_lb_target_group.green.arn }
output "listener_prod_arn"    { value = aws_lb_listener.prod.arn }
output "listener_staging_arn" { value = aws_lb_listener.staging.arn }
