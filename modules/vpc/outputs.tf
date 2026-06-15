output "vpc_id"         { value = aws_vpc.this.id }
output "pub_subnet_ids" { value = aws_subnet.public[*].id }
output "priv_subnet_ids"{ value = aws_subnet.private[*].id }
