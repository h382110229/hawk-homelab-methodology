# HAWK Homelab Methodology

Mac Pro 2013 个人基础设施的开发部署最佳实践。

## 概述

基于 2025-2026 最新研究（Anthropic Claude Code、Harper Reed、SWE-agent、GitOps 实践），整合为一套针对 Mac Pro 6,1 (2013) + Colima + Clash Verge + Cloudflare Tunnel 环境的全生命周期方法论。

## 目录

```
hawk-homelab-methodology/
├── docs/
│   └── methodology.md          # 完整方法论（7 阶段流水线）
└── README.md
```

## 方法论覆盖

| 阶段 | 方法论 | 工具 |
|------|--------|------|
| 需求规划 | Spec-Driven Development | ChatGPT o3 / Claude |
| 架构设计 | CLAUDE.md + Design Token | Claude Code / Hermes |
| 代码开发 | TDD + Writer/Reviewer 双 Agent | Claude Code / Aider |
| 测试验证 | 5 层验证 + 对抗审查 | pytest / Playwright / 子 Agent |
| 部署上线 | GitHub Actions + SSH + Docker Compose | deploy.sh / Colima 感知 |
| 监控运维 | Uptime Kuma + Healthchecks.io | 飞书/QQ 告警 |
| 持续演进 | Renovate + 反馈循环 | 自动依赖更新 |

## 环境约束

- Colima 重启会杀全部容器（用 `docker compose up -d` 代替）
- Clash TUN 劫持所有流量（确保 Merge Profile 有 Docker Hub DIRECT 规则）
- PT 做种不能中断（Transmission 必须 24/7）
- macOS 12.7.6 Tier 3（优先用 Docker 而非 host 安装）

## 配套 Hermes Skills（20 个）

### 本次新建（4 个）

| Skill | 用途 |
|-------|------|
| `homelab-cicd` | deploy.sh + GitHub Actions + Colima 感知部署 |
| `deploy-rollback` | 4 级回滚 + 镜像版本锁定 + 紧急恢复 |
| `uptime-monitoring` | Uptime Kuma + 飞书/QQ 告警 + Healthchecks.io |
| `renovate-homelab` | Docker 镜像自动更新 + 自动合并策略 |

### 已有（16 个）

| Skill | 阶段 |
|-------|------|
| `ai-development-workflows` | 需求 + 开发 |
| `plan` | 规划 |
| `spike` | 验证 |
| `claude-code` / `codex` / `opencode` | 开发 |
| `test-driven-development` | 开发 + 测试 |
| `systematic-debugging` | 测试 |
| `simplify-code` | 开发 |
| `requesting-code-review` / `github-code-review` | 测试 |
| `github-pr-workflow` | 部署 |
| `hawk-home-server` / `clash-verge` | 运维 |
| `hermes-agent` | 通用 |
| `safe-destructive-operations` | 通用 |

## License

Private — 个人项目。
