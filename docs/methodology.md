# HAWK Homelab 开发部署方法论

> 基于 2025-2026 最佳实践研究整合
> **针对 Mac Pro 6,1 (2013) 实际环境定制**
> 日期：2026-07-24 · v2.0

---

## 运行环境速查

| 项目 | 值 |
|------|-----|
| 硬件 | Mac Pro 6,1 (2013), Xeon E5-2697 v2, 64GB RAM, 1TB SSD |
| 系统 | macOS 12.7.6 (Tier 3 — Homebrew 无预编译 bottle) |
| Docker | Colima (QEMU x86_64, 8C/16GB/100GB, sshfs mount) |
| 网络 | Xiaomi 路由器 PPPoE → Mac Pro 192.168.31.236 |
| 代理 | Clash Verge TUN 模式 (拦截所有 SSL) |
| 公网 | Cloudflare Tunnel "hawk-home" (Docker 容器 hawk-cloudflared) |
| 域名 | hawkren.online (CF Access + OTP) |
| 数据 | /Volumes/Elements (12TB exFAT) |
| 服务 | 9 个 Docker 容器 (app-net 网络) |
| 消息 | 飞书 Bot + QQ Bot (Hermes Agent 管理) |
| GitHub | h382110229 (HTTPS via gh CLI) |

---

## 关键约束（影响所有阶段）

| 约束 | 影响 | 应对 |
|------|------|------|
| **Colima 重启杀所有容器** | ~30s 全站宕机，Transmission 中断 | 只用 `docker compose up -d` 重启单个服务 |
| **Colima SSH 转发 = IPv4 only** | 重启后 52888 端口可能丢失 | 部署后 `lsof -i :52888` 验证 |
| **Clash TUN 劫持所有流量** | Docker pull/npm install 可能被拦截 | 确保 Merge Profile 有 registry/docker.io DIRECT 规则 |
| **cloudflared 在 Docker 内** | 不是 host systemd 服务 | 用容器名管理，不碰 host launchd |
| **sshfs 不同步** | 新文件不在 Colima VM 内 | 用 `docker run alpine` 写入 volume |
| **PT 做种不能中断** | Transmission 必须 24/7 | 部署脚本排除 Transmission，单独处理 |
| **macOS 12.7.6 Tier 3** | Homebrew 无预编译 bottle | 优先用 Docker 而非 host 安装 |
| **内存 64GB 但 Colima 限 16GB** | Docker 容器总量受限 | 监控容器内存，避免 OOM |

---

## 总览：全生命周期流水线

```
[ 需求 & 规划 ] ──→ [ 架构 & 设计 ] ──→ [ 代码开发 ] ──→ [ 测试 & 验证 ]
     │                    │                    │                   │
     │  Spec-Driven       │  CLAUDE.md         │  TDD + AI         │  自动化验证
     │  Interview          │  Design Token      │  Writer/Reviewer  │  Hooks + CI
     │  ★ Hermes 调度      │                    │                   │
     │                    │                    │                   │
     ▼                    ▼                    ▼                   ▼
[ 持续演进 ] ◄─── [ 监控 & 运维 ] ◄─── [ 部署 & 上线 ] ◄─────────┘
     │                    │                    │
     │  Renovate          │  Uptime Kuma       │  GitHub Actions
     │  迭代反馈          │  ★ 飞书/QQ 告警     │  + SSH 部署
     │                    │  ★ Healthchecks    │  ★ Colima 感知
```

---

## Phase 1：需求 & 规划 — Spec-Driven Development

### 方法论：Harper Reed 的 Spec-Driven 流程

#### Step 1.1：Idea Honing（需求挖掘）

```
提示词模板：
"我想要做 [项目描述]。请一次问我一个问题来完善需求规格。
问到覆盖以下维度为止：
1. 目标用户和使用场景
2. 核心功能（MVP 范围）
3. 技术约束和偏好
4. 边界条件和异常处理
5. 验收标准
最后编译成一份 developer-ready specification。"
```

产出：`spec.md`

#### Step 1.2：Planning（计划生成）

```
提示词模板：
"基于 spec.md，制定分步实施蓝图：
- 拆成迭代式小块（每块 ≤ 2小时工作量）
- 每块有明确的测试驱动验证方式
- 输出 prompt_plan.md + todo.md"
```

产出：`prompt_plan.md` + `todo.md`

#### Step 1.3：★ Hermes 集成

Hermes Agent 可以在规划阶段自动：
- 调度 AI 进行 Spec 对话
- 保存产出到项目目录
- 创建 todo 追踪
- 定时提醒检查进度

---

## Phase 2：架构 & 设计 — 项目上下文工程

### CLAUDE.md 分层架构

```
~/.claude/CLAUDE.md          # 个人全局偏好
./CLAUDE.md                  # 项目级（git 提交）
./CLAUDE.local.md            # 本地覆盖（gitignore）
./.claude/rules/*.md         # 按文件类型/目录细分
```

**包含**：build/test 命令、项目特有规范、架构决策、常见陷阱
**排除**：代码能推断的事、标准规范、详细 API 文档

### ★ Mac Pro 项目的 CLAUDE.md 模板

```markdown
# CLAUDE.md

## 环境
- macOS 12.7.6, Docker via Colima
- DOCKER_HOST=unix:///Users/huoke/.colima/docker.sock
- Clash Verge TUN mode — all traffic intercepted
- Cloudflare Tunnel for public access

## 构建
- docker compose build
- docker compose up -d

## 部署约束
- NEVER use `colima restart` — kills all containers
- NEVER restart Transmission without user approval
- Check Clash proxy rules if Docker pull fails
- Colima sshfs doesn't sync — use docker volume for config

## 测试
- [project-specific test commands]
```

### Design Token 驱动

```
hawk-brand-system/tokens/
├── color/dark.json      → import 使用
├── color/light.json     → 主题切换
├── typography.json      → 字体
└── spacing.json         → 间距
```

---

## Phase 3：代码开发 — AI-Assisted TDD

### TDD 循环

```
1. 写测试（人工或 AI）→ 2. AI 实现 → 3. AI 运行测试 → 4. 人工/Agent 审查 → 5. 提交
```

### Writer/Reviewer 双 Agent

```
Writer（实现）──→ diff ──→ Reviewer（全新上下文审查）
      ▲                              │
      └──────── 反馈修改 ◄────────────┘
```

### 上下文管理

| 场景 | 操作 |
|------|------|
| 切换不相关任务 | `/clear` 或新 session |
| 上下文快满了 | `/compact` |
| 调研/探索 | 委派子 Agent |
| 纠正 3 次还没解决 | `/clear` + 重写 prompt |
| 大型迁移 | Fan-out 多 Agent 并行 |

**黄金法则**：新 session + 好 prompt > 长 session + 反复纠正

---

## Phase 4：测试 & 验证

### 5 层验证

| 层级 | 方式 | 工具 |
|------|------|------|
| L1 | Lint + Format | ESLint, Prettier, Ruff |
| L2 | 单元测试 | pytest, vitest |
| L3 | 构建检查 | `docker build`, `npm run build` |
| L4 | 集成测试 | Playwright |
| L5 | 对抗审查 | 子 Agent fresh context review |

### ★ Mac Pro 特有验证

- Docker 构建测试必须用 `colima ssh` 内的环境
- 网络相关测试需考虑 Clash TUN 影响
- 外部访问测试通过 Cloudflare Tunnel

---

## Phase 5：部署 & 上线 — ★ Colima 感知部署

### 推荐架构：GitHub Actions + SSH + Docker Compose

```
开发者 push → GitHub Actions → SSH 到 Mac Pro → deploy.sh
                                                    │
                                                    ├── git pull
                                                    ├── docker compose pull
                                                    ├── docker compose up -d (仅目标服务)
                                                    ├── health check
                                                    └── 飞书/QQ 通知
```

### ★ 安全操作矩阵

| 操作 | 安全等级 | 说明 |
|------|----------|------|
| `docker compose up -d` | ✅ 安全 | 仅重启目标服务栈 |
| `docker compose pull` | ✅ 安全 | 不影响运行中容器 |
| `docker exec` | ✅ 安全 | 在容器内执行命令 |
| `docker compose down && up` | ⚠️ 短暂中断 | 先停再启 |
| 新增容器 | ⚠️ 占内存 | Colima 限 16GB |
| `colima restart` | ❌ 危险 | 杀全部容器 ~30s |
| 修改 Colima 配置 | ❌ 危险 | 需重建 VM |
| `docker system prune` | ❌ 危险 | 可能删掉使用中的镜像 |

### ★ Clash Verge 共存

部署时 Docker Hub / npm / GitHub 等必须能访问。确保 Merge Profile 包含：

```yaml
rules:
  - DOMAIN-SUFFIX,registry-1.docker.io,DIRECT
  - DOMAIN-SUFFIX,github.com,DIRECT
  - DOMAIN-SUFFIX,npmjs.org,DIRECT
```

### ★ PT 做种保护

```bash
# deploy.sh 预检查
if [[ "$STACK" == "transmission" ]]; then
  echo "⚠️ WARNING: Deploying Transmission will interrupt PT seeding!"
  sleep 5  # 给用户 Ctrl+C 的时间
fi
```

### 通知集成

部署结果推送到飞书/QQ（通过 Hermes Agent）。

---

## Phase 6：监控 & 运维

### 推荐栈

| 工具 | 用途 | 部署 |
|------|------|------|
| **Uptime Kuma** | HTTP/TCP 健康检查 + 告警 | Docker 容器 |
| **Healthchecks.io** | Dead man's switch | 免费云服务 |
| **飞书/QQ Bot** | 告警推送 | Hermes Agent |

### 监控项清单

| 服务 | 检查方式 | 间隔 |
|------|----------|------|
| hawk-caddy | HTTP :80 | 30s |
| hawk-portainer | HTTP :9000 | 60s |
| hawk-filebrowser | HTTP :80 | 60s |
| hawk-nas-ui | HTTP :8081 | 60s |
| hawk-transmission | HTTP :9091 | 60s |
| hawk-postgres | TCP :5432 | 120s |
| hawkren.online | HTTPS | 60s |

### ★ Colima VM 内存监控

```bash
# Colima VM 内存使用
colima ssh -- free -h

# Docker 容器内存
docker stats --no-stream --format "table {{.Name}}\t{{.MemUsage}}"
```

---

## Phase 7：持续演进

### 迭代节奏

| 活动 | 频率 | 工具 |
|------|------|------|
| 代码提交 | 每个功能点 | Git + GitHub |
| 部署 | Push to main 自动触发 | GitHub Actions + SSH |
| 依赖更新 | 每周 Renovate PR | Renovate |
| 健康检查 | 每 60s | Uptime Kuma |
| 备份验证 | 每月 | Healthchecks.io |
| 架构回顾 | 每月 | Hermes 提醒 |

---

## AI 工具矩阵

| 工具 | 最佳用途 | 阶段 |
|------|----------|------|
| **Hermes Agent** | 多工具协调、定时任务、飞书/QQ 通知 | 全生命周期 |
| **Claude Code** | 交互式编码、TDD、代码审查 | 开发 + 测试 |
| **ChatGPT/o3** | 需求挖掘、Spec 生成 | 规划 |
| **Codex** | 编码、PR 实现 | 开发 |
| **Aider** | 快速代码修改 | 开发 |

### 多工具协作流

```
[ChatGPT/o3]  需求挖掘 → spec.md
      ↓
[Claude Code]  计划 → prompt_plan.md
      ↓
[Claude Code]  编码 + 测试
      ↓
[Hermes Agent] 调度子 Agent 对抗审查
      ↓
[GitHub Actions] CI/CD → 测试 + SSH 部署
      ↓
[Hermes Agent] 监控 + 飞书/QQ 告警
```

---

## Skill 矩阵（Hermes 已配备）

### Phase 1 — 需求规划

| Skill | 用途 |
|-------|------|
| `ai-development-workflows` | Spec-Driven + TDD + 多 Agent + 上下文管理 |
| `spike` | 一次性实验验证可行性 |
| `plan` | 写可执行的实施计划 |

### Phase 2 — 架构设计

| Skill | 用途 |
|-------|------|
| `plan` | 详细实施计划（含文件路径、代码、命令） |
| `brand-design-system` | 品牌 Design Token 驱动 UI |

### Phase 3 — 代码开发

| Skill | 用途 |
|-------|------|
| `claude-code` | Claude Code CLI 编码委托 |
| `codex` | OpenAI Codex 编码委托 |
| `opencode` | OpenCode 编码委托 |
| `test-driven-development` | TDD 红绿重构 |
| `ai-development-workflows` | Writer/Reviewer + Fan-out + 上下文管理 |
| `simplify-code` | 3 Agent 并行代码清理 |

### Phase 4 — 测试验证

| Skill | 用途 |
|-------|------|
| `systematic-debugging` | 4 阶段根因调试 |
| `test-driven-development` | 测试驱动验证 |
| `requesting-code-review` | 提交前安全/质量门 |
| `github-code-review` | PR 审查 |

### Phase 5 — 部署上线

| Skill | 用途 |
|-------|------|
| `homelab-cicd` | ★ deploy.sh + GitHub Actions + Colima 感知部署 |
| `deploy-rollback` | ★ 4 级回滚 + 镜像版本锁定 |
| `github-pr-workflow` | PR → CI → 合并 → 部署 |
| `hawk-home-server` | 服务架构 + Colima + Clash + CF Tunnel |

### Phase 6 — 监控运维

| Skill | 用途 |
|-------|------|
| `uptime-monitoring` | ★ Uptime Kuma + 飞书/QQ 告警 |
| `hawk-home-server` | 数据持久化 + 备份 |
| `clash-verge` | 代理配置管理 |

### Phase 7 — 持续演进

| Skill | 用途 |
|-------|------|
| `renovate-homelab` | ★ Docker 镜像自动更新 |

### 全生命周期通用

| Skill | 用途 |
|-------|------|
| `hermes-agent` | Hermes 自身配置和扩展 |
| `safe-destructive-operations` | 危险操作安全规则 |

### Skill 关联图

```
ai-development-workflows ←── plan ←── spike
         ↕                    ↕
    claude-code          test-driven-development
         ↕                    ↕
    codex/opencode       systematic-debugging
                              ↕
                      simplify-code / requesting-code-review
                              ↕
                       github-pr-workflow ←── github-code-review
                              ↕
                        homelab-cicd ←── hawk-home-server
                              ↕
                    ┌─────────┼─────────┐
              deploy-rollback  │   renovate-homelab
                               │
                      uptime-monitoring
```

★ = 本次新建的 Skill（4 个）

---

## 新项目快速启动清单

- [ ] `git init` + 创建仓库
- [ ] 编写 `CLAUDE.md`（含 Mac Pro 环境约束）
- [ ] Spec-Driven 流程产出 `spec.md`
- [ ] 创建 `.claude/settings.json`（Hooks）
- [ ] 创建 GitHub Actions workflow（测试 + 部署）
- [ ] 配置 Renovate（依赖自动更新）
- [ ] 部署到 Mac Pro（`docker compose up -d`，不用 `colima restart`）
- [ ] 添加 Uptime Kuma 监控
- [ ] 配置 Healthchecks.io dead man's switch
- [ ] 导入 HAWK Design Token
- [ ] 部署结果推送到飞书/QQ

---

## 参考来源

- [Anthropic Claude Code Docs](https://code.claude.com/docs/en/) — 官方最佳实践
- [Harper Reed's LLM Codegen Workflow](https://harper.blog/2025/02/06/my-llm-codegen-workflow-atm/) — Spec-Driven
- [Karan Sharma's Homelab Deploy](https://mrkaran.dev) — rsync + SSH
- [teqqy.de GitOps](https://teqqy.de) — Gitea + Renovate + Webhook
- [Coolify](https://github.com/coollabsio/coolify) — 自托管 PaaS
- [Dokploy](https://github.com/Dokploy/dokploy) — 轻量 PaaS
- [SWE-agent](https://github.com/SWE-agent/SWE-agent) — 多 Agent 编码
- HAWK Homelab 实际运维经验 — Colima/Clash/CF Tunnel 共存

---

*本文档由 HAWK × Hermes Agent 协作完成。针对 Mac Pro 6,1 (2013) 实际环境定制。*
