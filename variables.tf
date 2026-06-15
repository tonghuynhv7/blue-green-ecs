variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-southeast-1"
}

variable "project" {
  description = "Project name, dùng làm prefix cho tất cả resource"
  type        = string
  default     = "myapp"
}

variable "env" {
  description = "Environment: dev | staging | prod"
  type        = string
  default     = "dev"
}

# ─── Networking ─────────────────────────────────────────────────────────────
variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "azs" {
  type    = list(string)
  default = ["ap-southeast-1a", "ap-southeast-1b"]
}

variable "pub_cidrs" {
  type    = list(string)
  default = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "priv_cidrs" {
  type    = list(string)
  default = ["10.0.11.0/24", "10.0.12.0/24"]
}

# ─── App ────────────────────────────────────────────────────────────────────
variable "app_port" {
  description = "Container port của NodeJS app"
  type        = number
  default     = 3000
}

variable "task_cpu" {
  description = "CPU units cho ECS task (256 = 0.25 vCPU)"
  type        = number
  default     = 256
}

variable "task_memory" {
  description = "Memory (MiB) cho ECS task"
  type        = number
  default     = 512
}

# ─── Blue ────────────────────────────────────────────────────────────────────
variable "blue_image_tag" {
  description = "Docker image tag cho Blue cluster (production)"
  type        = string
  default     = "v1.0.0"
}

variable "blue_desired_count" {
  description = "Số lượng task chạy trên Blue cluster"
  type        = number
  default     = 2
}

# ─── Green ───────────────────────────────────────────────────────────────────
variable "green_image_tag" {
  description = "Docker image tag cho Green cluster (staging / new version)"
  type        = string
  default     = "v1.0.1"
}

variable "green_desired_count" {
  description = "Số lượng task chạy trên Green cluster"
  type        = number
  default     = 1
}
