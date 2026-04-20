variable "project_name" {
  type        = string
  description = "프로젝트 이름"
}

variable "environment" {
  type        = string
  description = "배포 환경 (dev, prod)"
}

# ── VPC 연결 ───────────────────────────────────────────────────────────
variable "vpc_id" {
  type        = string
  description = "VPC ID (vpc 모듈 output)"
}

variable "eks_subnet_ids" {
  type        = list(string)
  description = "EKS 워커 노드 서브넷 ID 목록 (vpc 모듈 output.eks_subnet_ids)"
}

variable "eks_sg_id" {
  type        = string
  description = "EKS 기본 보안 그룹 ID (vpc 모듈 output) — RDS/Redis SG 소스로 이미 등록되어 있음"
}

# ── 클러스터 설정 ──────────────────────────────────────────────────────
variable "cluster_version" {
  type        = string
  description = "EKS 클러스터 버전"
  default     = "1.29"
}

variable "public_access_cidrs" {
  type        = list(string)
  description = "EKS API 서버 퍼블릭 접근 허용 CIDR 목록 (운영 시 사무실 IP로 좁힐 것)"
  default     = ["0.0.0.0/0"]
}

# ── 워커 노드 설정 ─────────────────────────────────────────────────────
variable "instance_type" {
  type        = string
  description = "워커 노드 EC2 인스턴스 타입"
  default     = "t3.large"
}

variable "node_min_size" {
  type        = number
  description = "ASG 최소 노드 수"
  default     = 2
}

variable "node_desired_size" {
  type        = number
  description = "ASG 희망 노드 수"
  default     = 2
}

variable "node_max_size" {
  type        = number
  description = "ASG 최대 노드 수 (AZ별 최대 2대 = 전체 4대)"
  default     = 4
}

variable "node_volume_size" {
  type        = number
  description = "워커 노드 루트 볼륨 크기 (GB)"
  default     = 50
}

variable "node_ami_id" {
  type        = string
  description = "EKS 최적화 AMI ID (Amazon Linux 2). AWS 콘솔 또는 아래 명령으로 조회: aws ec2 describe-images --owners amazon --filters 'Name=name,Values=amazon-eks-node-<version>-v*' --query 'sort_by(Images,&CreationDate)[-1].ImageId' --output text"
}

variable "target_group_arns" {
  type        = list(string)
  description = "ASG에 연결할 ALB 타겟 그룹 ARN 목록"
  default     = []
}
