# Blue-Green ECS Terraform

Triển khai Blue-Green deployment cho ECS Fargate + ALB theo đúng kiến trúc lab.

## Cấu trúc

```
blue-green-ecs/
├── main.tf                  # Root module, gọi 4 child module
├── variables.tf
├── outputs.tf
├── terraform.tfvars.example
├── switch-traffic.sh        # Script swap listener 80 khi done test
└── modules/
    ├── vpc/                 # VPC, subnets, IGW, NAT, route tables
    ├── ecr/                 # ECR repo + lifecycle policy
    ├── alb/                 # ALB, 2 Target Groups, listener :80 và :81
    └── ecs/                 # ECS Cluster, Task Def, Service, IAM, SG
        (dùng chung cho Blue và Green, phân biệt bằng var.color)
```

## Quick Start

### 1. Chuẩn bị

```bash
# Copy và chỉnh tfvars
cp terraform.tfvars.example terraform.tfvars

# Đảm bảo AWS credentials đã config
aws configure list
# hoặc export AWS_PROFILE=your-profile
```

### 2. Deploy infrastructure

```bash
terraform init
terraform plan
terraform apply
```

### 3. Build và push image lên ECR

```bash
# Lấy ECR URL từ output
ECR_URL=$(terraform output -raw ecr_repo_url)
REGION="ap-southeast-1"

# Login ECR
aws ecr get-login-password --region $REGION | \
  docker login --username AWS --password-stdin $ECR_URL

# Build và push v1.0.0 (Blue)
docker build -t $ECR_URL:v1.0.0 .
docker push $ECR_URL:v1.0.0

# Build và push v1.0.1 (Green)
docker build -t $ECR_URL:v1.0.1 .
docker push $ECR_URL:v1.0.1
```

### 4. Kiểm tra

```bash
ALB_DNS=$(terraform output -raw alb_dns_name)

# Production (Blue) — port 80
curl http://$ALB_DNS/health

# Staging (Green) — port 81, Tester dùng cái này
curl http://$ALB_DNS:81/health
```

### 5. Switch traffic sang Green (sau khi Tester OK)

```bash
chmod +x switch-traffic.sh
./switch-traffic.sh green
# Để rollback:
./switch-traffic.sh blue
```

## Lưu ý quan trọng

| Điểm | Giải thích |
|------|-----------|
| `lifecycle ignore_changes` trên ECS service | Terraform sẽ không ghi đè task definition khi Jenkins deploy — Jenkins quản lý cái này |
| `lifecycle ignore_changes` trên ALB listener | Terraform không rollback sau khi script switch traffic |
| `target_type = "ip"` trên Target Group | Bắt buộc khi dùng Fargate (không có EC2 instance) |
| NAT Gateway | ECS task trong private subnet cần NAT để pull ECR image |

## Biến quan trọng cần đổi trước khi dùng thật

```hcl
# terraform.tfvars
project    = "ten-project-cua-ban"   # tên resource sẽ có prefix này
env        = "prod"
blue_image_tag  = "v1.0.0"           # image đang chạy production
green_image_tag = "v1.0.1"           # image mới cần test
```
