# hawk-homelab-methodology — 项目规格 (Spec)

> 版本：v1.0 · 2026-07-24
> 方法论验证项目：用方法论构建方法论本身

---

## 1. 项目定位

**一句话**：Mac Pro 2013 Homelab 的全生命周期开发方法论 + 可执行脚手架 + Hermes Skill。

**目标**：Hermes 调用这个方法论后，能完整地从 0 到 1 开发、测试、部署一个 homelab 项目。

## 2. 目标用户

| 用户 | 场景 |
|------|------|
| **Hermes Agent** | 主要用户 — 读取方法论 + 调用 Skill 自动化开发 |
| **Hawk（人工）** | 审核决策 — Spec 审批、架构确认、部署授权 |
| **其他 AI Agent** | 次要 — Claude Code / Codex 读取 CLAUDE.md 执行 |

## 3. 交付物

### 3.1 方法论文档
- `docs/methodology.md` — 7 阶段完整方法论（已有，需持续迭代）
- `docs/faq.md` — 常见坑 + FAQ
- `docs/multi-project.md` — 多项目管理规范

### 3.2 CLI 工具（三种实现）

| 实现 | 命令 | 说明 |
|------|------|------|
| Shell | `curl -fsSL .../install.sh \| bash` | 最轻量，Mac Pro 原生 |
| Node.js | `npx create-hawk-homelab` | npm 生态 |
| Python | `pipx install hawk-homelab && hawk-homelab init` | pipx |

三种实现功能一致：交互式/命令式双模式初始化项目。

### 3.3 Hermes Skill
- Skill 名：`create-hawk-homelab`
- 触发词：`初始化 homelab 项目`、`新建 homelab 服务`、`scaffold homelab`
- 功能：调用 CLI 工具生成项目骨架

### 3.4 项目模板（脚手架生成物）

```
my-project/
├── CLAUDE.md                        # AI 指令（含 Mac Pro 约束）
├── .claude/
│   ├── settings.json                # Hooks（lint/format）
│   └── rules/
│       ├── docker-compose.md        # Compose 规范
│       └── deploy-safety.md         # 部署安全规则
├── docker-compose.yml               # 服务定义 + healthcheck
├── .github/workflows/
│   ├── deploy.yml                   # Push → 测试 → SSH 部署
│   └── renovate-deploy.yml          # Renovate 合并 → 自动部署
├── deploy.sh                        # 部署脚本（Colima 感知）
├── rollback.sh                      # 回滚脚本
├── pre-deploy-check.sh              # 部署前安全检查
├── renovate.json                    # 依赖自动更新配置
├── .hermes/
│   ├── scripts/
│   │   ├── health-check.sh          # 服务健康检查
│   │   ├── notify.sh                # 飞书/QQ 通知
│   │   └── backup.sh                # 数据备份
│   └── cron/
│       ├── health-monitor.md        # 定时监控 job
│       └── backup.md                # 定时备份 job
├── docs/
│   ├── spec.md                      # 空 Spec 模板
│   ├── prompt_plan.md               # AI 编码指令序列模板
│   └── todo.md                      # 人工检查清单模板
├── tests/
│   ├── smoke-test.sh                # 冒烟测试
│   └── integration-test.sh          # 集成测试模板
└── README.md
```

## 4. 技术约束

| 约束 | 说明 |
|------|------|
| 目标环境 | Mac Pro 6,1 (2013), macOS 12.7.6 专用 |
| Docker | Colima (QEMU x86_64), DOCKER_HOST 固定路径 |
| 网络 | Clash Verge TUN, Cloudflare Tunnel |
| PT 保护 | Transmission 不能中断 |
| CLI 兼容 | Shell (bash 3.2+), Node.js (18+), Python (3.9+) |
| Skill 格式 | 遵循 Hermes SKILL.md 规范 |

## 5. 接口设计

### CLI 双模式

```bash
# 命令式 — 直接生成
create-hawk-homelab my-app --port 8080 --services web,api,db

# 交互式 — 问答收敛
create-hawk-homelab
> 项目名称？ my-app
> 服务类型？ web + api + postgres
> 对外端口？ 8080
> 是否需要数据库？ yes (postgres 16)
> 是否需要 Redis？ no
> ...
> ✅ 项目已生成到 ./my-app/
```

### Skill 触发

```
用户: "初始化 homelab 项目 my-app，端口 8080，需要 postgres"
Hermes: → 加载 create-hawk-homelab skill → 调用 CLI → 返回结果
```

## 6. 验收标准

- [ ] `create-hawk-homelab my-test` 生成完整项目骨架
- [ ] 生成的 `CLAUDE.md` 含所有 Mac Pro 环境约束
- [ ] 生成的 `deploy.sh` 能在 Mac Pro 上执行（含 Colima 检查、Clash 检查）
- [ ] 生成的 `docker-compose.yml` 含 healthcheck 配置
- [ ] 生成的 GitHub Actions 能 SSH 到 Mac Pro 部署
- [ ] 生成的 `renovate.json` 自动排除 Postgres major 版本
- [ ] Hermes 调用 Skill 能完整走通 7 阶段
- [ ] 另一个 Agent 读取 CLAUDE.md 后能独立开发

## 7. 范围外（不做）

- Kubernetes / k3s 支持
- 多服务器支持
- GUI 管理面板
- 非 macOS 平台
- Postgres 迁移自动化（手动处理）

---

*本 Spec 由 Spec-Driven 流程产出，作为 hawk-homelab-methodology 的开发规格。*
