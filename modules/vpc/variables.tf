variable "project"    { type = string }
variable "env"        { type = string }
variable "vpc_cidr"   { type = string }
variable "azs"        { type = list(string) }
variable "pub_cidrs"  { type = list(string) }
variable "priv_cidrs" { type = list(string) }
