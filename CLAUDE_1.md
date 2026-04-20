# CLAUDE.md - Pickup Platform Infrastructure

## 프로젝트 개요
픽업 예약 플랫폼의 AWS 인프라를 Terraform으로 구성하는 프로젝트

## 팀 구성
- 인프라 팀 2명 (콘솔 + Terraform 병행)
- 백엔드 팀은 별도 (Pod 배포는 나중에)

---

## 아키텍처 요약

### AWS 리전
- ap-northeast-2 (서울)

### VPC 구성 (10.0.0.0/16)
| Subnet | CIDR | 용도 |
|--------|------|------|
| Public AZ-a | 10.0.1.0/24 | ALB, NAT GW |
| Public AZ-c | 10.0.2.0/24 | ALB (대기), NAT GW |
| EKS AZ-a | 10.0.3.0/24 | Worker Node |
| EKS AZ-c | 10.0.4.0/24 | Worker Node |
| 실시간 AZ-a | 10.0.5.0/24 | SQS, Redis |
| 실시간 AZ-c | 10.0.6.0/24 | SQS, Redis Replica |
| 데이터 AZ-a | 10.0.7.0/24 | RDS Primary |
| 데이터 AZ-c | 10.0.8.0/24 | RDS Replica |

### 주요 리소스
- **EKS**: Cluster 1.29 + Self-managed Node Group (ASG)
  - dev: t3.medium x1 (min 1, desired 1, max 2)
  - prod: t3.large x2 (min 2, desired 2, max 4)
- **RDS**: PostgreSQL 16, t3.small (dev) / t3.medium (prod)
- **ElastiCache**: Redis 7.x, cache.t3.micro
- **S3**: 이미지, 로그, 백업 버킷
- **SQS**: 예약 큐 + DLQ
- **SNS**: 알림 토픽 (SQS 구독 연결)
- **ALB**: HTTPS (443), WAF 연결
- **Secrets Manager**: RDS 비밀번호 AWS managed (하드코딩 금지)

---

## Terraform 폴더 구조

```
sallijang-infra/
├── environments/
│   ├── dev/
│   │   ├── main.tf          # 모듈 호출
│   │   ├── variables.tf     # 변수 정의
│   │   ├── terraform.tfvars # 개발 환경 값
│   │   ├── outputs.tf
│   │   └── backend.tf       # local 백엔드 (현재 로컬 tfstate)
│   └── prod/
│       ├── main.tf          # ⚠️ 미구현 (비어있음)
│       ├── variables.tf
│       ├── terraform.tfvars # ⚠️ 비어있음
│       ├── outputs.tf
│       ├── backend.tf       # S3 백엔드 (pick-up-terraform-state-prod)
│       └── versions.tf      # prod 전용 provider 버전 고정
│
├── modules/
│   ├── vpc/          # VPC, Subnet, IGW, NAT, Route Table, SG
│   ├── eks/          # EKS Cluster, Self-managed Node Group (ASG + Launch Template), IRSA
│   ├── rds/          # PostgreSQL 16, Subnet Group (Secrets Manager managed pw)
│   ├── elasticache/  # Redis Cluster
│   ├── s3/           # S3 Buckets, Lifecycle
│   ├── sqs/          # SQS Queue, DLQ
│   ├── sns/          # SNS Topic, SQS 구독
│   └── alb/          # ALB, Target Group, WAF
│
├── versions.tf       # 루트 Terraform/Provider 버전
└── CLAUDE_1.md
```

---

## 모듈별 상세

### modules/vpc ✅ 완료
- VPC (10.0.0.0/16)
- Subnet 8개 (Public 2, EKS 2, 실시간 2, 데이터 2)
- Internet Gateway
- NAT Gateway x2 (각 AZ)
- Route Table (Public, Private)
- Security Groups (EKS, RDS, Redis, ALB)

### modules/eks ✅ 완료
- EKS Cluster (버전 1.29)
- **Self-managed Node Group** (Managed Node Group 아님)
  - Launch Template + ASG 방식
  - EC2 인스턴스 타입: **dev t3.medium / prod t3.large** (variable로 주입)
  - 노드 수: dev min 1, desired 1, max 2 / prod min 2, desired 2, max 4
  - AMI: SSM Parameter에서 EKS Optimized AMI 자동 조회 (Amazon Linux 2)
  - IMDSv2 강제, EBS 암호화 (gp3 50GB)
  - Cluster Autoscaler 태그 포함 (`desired_capacity` ignore_changes)
- OIDC Provider (IRSA용)
- EKS Access Entry (워커 노드 IAM Role 등록)

### modules/rds ✅ 완료
- RDS PostgreSQL **16**
- 인스턴스: db.t3.small (dev) / db.t3.medium (prod)
- Storage: gp3, 암호화
- **비밀번호**: `manage_master_user_password = true` → AWS Secrets Manager 자동 관리 (하드코딩 금지)
- Multi-AZ: 현재 false (dev 기준, prod 적용 시 변경 필요)
- skip_final_snapshot: true (dev), prod 전환 시 false로 변경 필요
- Subnet Group

### modules/elasticache ✅ 완료
- Redis 7.x
- 노드: cache.t3.micro (dev) / cache.t3.small (prod)
- Subnet Group

### modules/s3 ✅ 완료
- `{project}-{env}-images` (상품 이미지)
- `{project}-{env}-logs` (애플리케이션 로그)
- `{project}-{env}-backup` (DB 스냅샷)
- 퍼블릭 접근 차단, 서버 사이드 암호화

### modules/sqs ✅ 완료
- `{project}-{env}-reservation` (예약 처리 메인 큐)
- `{project}-{env}-reservation-dlq` (Dead Letter Queue, 보관 14일)
- 3회 수신 실패 시 DLQ 이동
- SQS managed SSE 암호화

### modules/sns ✅ 완료
- `{project}-{env}-notification` (SNS 토픽)
- SNS → SQS 구독 (`sqs_endpoint_arn` 변수로 연결, raw message delivery)
- 전송 실패 CloudWatch Logs 피드백 (IAM Role 포함)
- **sqs 모듈과 별도 모듈로 분리됨** (`modules/sns/`)

### modules/alb ⚠️ 구현 여부 확인 필요
- Application Load Balancer
- HTTPS Listener (443)
- HTTP → HTTPS 리다이렉트
- Target Group (EKS 연결용)
- WAF Web ACL

---

## 환경별 현황

| 항목 | dev | prod |
|------|-----|------|
| backend | local (로컬 tfstate) | S3 + DynamoDB 락 |
| versions.tf | 루트 공유 | 환경별 독립 (`environments/prod/versions.tf`) |
| main.tf | vpc, elasticache, rds 연결됨 | ⚠️ 비어있음 (미구현) |
| terraform.tfvars | 완성 | ⚠️ 비어있음 |

---

## 작업 담당

| 담당 | 모듈 |
|------|------|
| 나 | vpc, eks, alb |
| 팀원 | rds, elasticache, s3, sqs, sns |

---

## Naming Convention

```
{project}-{env}-{resource}

예시:
- pickup-dev-vpc
- pickup-dev-eks-cluster
- pickup-dev-rds
- pickup-dev-redis
- pickup-dev-alb
- pickup-dev-notification  (SNS)
- pickup-dev-reservation   (SQS)
```

---

## 작업 순서 (의존성)

1. **vpc/** - 모든 리소스의 기반
2. **rds/, elasticache/** - VPC 완료 후 병렬 가능
3. **eks/** - VPC 완료 후
4. **s3/, sqs/, sns/** - 독립적, 언제든 가능 (sns는 sqs ARN 필요)
5. **alb/** - VPC, EKS 완료 후

---

## 주의사항

1. **dev backend는 현재 local** - 팀 협업 시 S3로 전환 필요
2. **DB 비밀번호는 Secrets Manager에서 관리** - `manage_master_user_password = true`, terraform.tfvars에 절대 하드코딩 금지
3. **태그 필수** - Project, Environment, ManagedBy
4. **모듈 outputs 활용** - vpc_id, subnet_ids 등 다른 모듈에서 참조
5. **prod main.tf 미작성** - prod 배포 전 반드시 모듈 연결 작업 필요
6. **EKS Self-managed**: Cluster Autoscaler가 desired_capacity 관리, Terraform이 덮어쓰지 않도록 `ignore_changes` 설정됨

---

## 자주 쓰는 명령어

```bash
# 초기화
cd environments/dev
terraform init

# 계획 확인
terraform plan

# 적용
terraform apply

# 특정 모듈만 적용
terraform apply -target=module.vpc

# 상태 확인
terraform state list
```

---

## EKS Pod 배포 (백엔드 팀 - 나중에)

인프라 팀은 여기까지만! 아래는 백엔드 팀이 나중에 작업:
- Deployment YAML
- Service, Ingress
- HPA 설정
- ArgoCD Application

---

## 참고 링크

- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest)
- [EKS Module](https://registry.terraform.io/modules/terraform-aws-modules/eks/aws/latest)
- [VPC Module](https://registry.terraform.io/modules/terraform-aws-modules/vpc/aws/latest)
