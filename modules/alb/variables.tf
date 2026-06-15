variable "project"       { type = string }
variable "env"           { type = string }
variable "vpc_id"        { type = string }
variable "pub_subnet_ids"{ type = list(string) }
variable "app_port" {
  type    = number
  default = 3000
}
