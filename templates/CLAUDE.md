# {{PROJECT_NAME}}

> 由 create-hawk-homelab 生成 · Mac Pro 2013 Homelab 项目

## 项目概述

{{PROJECT_DESCRIPTION}}

## 目标环境

| 约束 | 值 |
|------|-----|
| 硬件 | Mac Pro 6,1 (2013), 64GB RAM, D500 GPU x2 |
| 系统 | macOS 12.7.6 (Monterey) |
| Docker | Colima (QEMU x86_64 emulation) |
| Docker Socket | `unix:///Users/huoke/.colima/docker.sock` |
| 网络代理 | Clash Verge TUN 模式（拦截所有流量） |
| 公网访问 | Cloudflare Tunnel (container: hawk-cloudflared) |
| PT 服务 | Transmission (部署期间 **不能中断**) |
| 部署目标 | SSH → 192.168.31.236 |

## 关键规则

### Docker / Colima

- **禁止** `colima restart` — 会中断所有容器，包括 Transmission
- Docker socket 固定: `unix:///Users/huoke/.colima/docker.sock`
- 所有 compose 命令必须先 `export DOCKER_HOST=unix:///Users/huoke/.colima/docker.sock`
- 镜像必须指定版本标签，**禁止** `:latest`
- 使用 `docker compose`（V2），不用 `docker-compose`（V1）

### 部署安全

- 部署前必须运行 `pre-deploy-check.sh`
- 部署失败必须回滚，不能留半成品
- 数据库变更必须先备份
- 每次部署必须验证 healthcheck 通过

### 网络

- Clash Verge TUN 模式会拦截所有网络流量
- Cloudflare Tunnel 通过 `hawk-cloudflared` 容器提供公网访问
- 服务间通信使用 Docker 内部网络 `app-net`

### PT 保护

- Transmission 是核心服务，**绝对不能被重启/停止**
- 部署脚本不能影响其他正在运行的容器
- 使用 `docker compose up -d --no-deps` 只操作目标服务

## 开发流程

```bash
# 1. 开发
# 编辑代码...

# 2. 本地测试
docker compose up -d
curl -f http://localhost:{{PORT}}/health

# 3. 部署前检查
bash pre-deploy-check.sh

# 4. 部署
bash deploy.sh

# 5. 验证
curl -f https://{{PROJECT_NAME}}.your-domain.com/health
```

## 端口分配

| 服务 | 端口 |
|------|------|
| {{PROJECT_NAME}} | {{PORT}} |

## 目录结构

```
{{PROJECT_NAME}}/
├── CLAUDE.md                # 本文件 — AI 指令
├── docker-compose.yml       # 服务定义
├── deploy.sh                # 部署脚本
├── rollback.sh              # 回滚脚本
├── pre-deploy-check.sh      # 部署前检查
├── .github/workflows/       # CI/CD
├── .hermes/                 # Hermes 集成
├── docs/                    # 文档
└── tests/                   # 测试
```
