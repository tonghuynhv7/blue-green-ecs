terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# ─── VPC ────────────────────────────────────────────────────────────────────
module "vpc" {
  source = "./modules/vpc"

  project    = var.project
  env        = var.env
  vpc_cidr   = var.vpc_cidr
  azs        = var.azs
  pub_cidrs  = var.pub_cidrs
  priv_cidrs = var.priv_cidrs
}

# ─── ECR ────────────────────────────────────────────────────────────────────
module "ecr" {
  source = "./modules/ecr"

  project = var.project
  env     = var.env
}

# ─── ALB ────────────────────────────────────────────────────────────────────
module "alb" {
  source = "./modules/alb"

  project    = var.project
  env        = var.env
  vpc_id     = module.vpc.vpc_id
  pub_subnet_ids = module.vpc.pub_subnet_ids
}

# ─── ECS BLUE ───────────────────────────────────────────────────────────────
module "ecs_blue" {
  source = "./modules/ecs"

  project          = var.project
  env              = var.env
  color            = "blue"
  vpc_id           = module.vpc.vpc_id
  priv_subnet_ids  = module.vpc.priv_subnet_ids
  alb_sg_id        = module.alb.alb_sg_id
  target_group_arn = module.alb.tg_blue_arn
  ecr_repo_url     = module.ecr.repo_url
  image_tag        = var.blue_image_tag
  app_port         = var.app_port
  desired_count    = var.blue_desired_count
  cpu              = var.task_cpu
  memory           = var.task_memory
  aws_region       = var.aws_region
}

# ─── ECS GREEN ──────────────────────────────────────────────────────────────
module "ecs_green" {
  source = "./modules/ecs"

  project          = var.project
  env              = var.env
  color            = "green"
  vpc_id           = module.vpc.vpc_id
  priv_subnet_ids  = module.vpc.priv_subnet_ids
  alb_sg_id        = module.alb.alb_sg_id
  target_group_arn = module.alb.tg_green_arn
  ecr_repo_url     = module.ecr.repo_url
  image_tag        = var.green_image_tag
  app_port         = var.app_port
  desired_count    = var.green_desired_count
  cpu              = var.task_cpu
  memory           = var.task_memory
  aws_region       = var.aws_region
}
