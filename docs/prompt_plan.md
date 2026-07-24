# hawk-homelab-methodology — 实施蓝图

> **For Hermes:** Use subagent-driven-development skill to implement this plan task-by-task.
>
> **Goal:** 构建 Mac Pro Homelab 全生命周期开发脚手架 + CLI + Hermes Skill
>
> **Architecture:** 模板文件 → Shell/Node/Python 三种 CLI → Hermes Skill 封装 → 端到端测试
>
> **Tech Stack:** bash, Node.js (18+), Python (3.9+), Hermes SKILL.md

---

## Task 1: 项目模板文件 — docker-compose.yml

**Objective:** 创建模板用的 docker-compose.yml，含 healthcheck 配置

**Files:**
- Create: `templates/docker-compose.yml`

**Step 1: 创建模板**

```yaml
# docker-compose.yml — {{PROJECT_NAME}} 服务定义
# 由 create-hawk-homelab 生成
version: '3.8'

services:
  {{PROJECT_NAME}}:
    image: {{IMAGE}}:{{VERSION}}
    container_name: hawk-{{PROJECT_NAME}}
    restart: unless-stopped
    ports:
      - "{{PORT}}:{{INTERNAL_PORT}}"
    volumes:
      - {{PROJECT_NAME}}-data:/data
    networks:
      - app-net
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:{{INTERNAL_PORT}}/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 10s

volumes:
  {{PROJECT_NAME}}-data:

networks:
  app-net:
    external: true
```

**Step 2: Commit**

```bash
git add templates/docker-compose.yml
git commit -m "feat: add docker-compose template with healthcheck"
```

---

## Task 2: 项目模板文件 — CLAUDE.md

**Objective:** 创建 CLAUDE.md 模板，含所有 Mac Pro 环境约束

**Files:**
- Create: `templates/CLAUDE.md`

**Step 1: 创建模板**

内容参考 `spec.md` 中的技术约束 + `hawk-home-server` skill 中的环境信息。

**Step 2: Commit**

---

## Task 3: 项目模板文件 — .claude/rules/

**Objective:** 创建 Claude Code 规则文件模板

**Files:**
- Create: `templates/.claude/settings.json`
- Create: `templates/.claude/rules/docker-compose.md`
- Create: `templates/.claude/rules/deploy-safety.md`

**Step 1: 创建 settings.json（含 Hooks）**

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Write|Edit",
        "command": "echo 'File saved: $FILE'"
      }
    ]
  }
}
```

**Step 2: 创建 deploy-safety.md 规则**

关键规则：不能 colima restart、不能中断 Transmission、部署前检查 Clash。

**Step 3: Commit**

---

## Task 4: 项目模板文件 — GitHub Actions

**Objective:** 创建 deploy.yml 和 renovate-deploy.yml 模板

**Files:**
- Create: `templates/.github/workflows/deploy.yml`
- Create: `templates/.github/workflows/renovate-deploy.yml`

**Step 1: 创建 deploy.yml**

SSH 到 Mac Pro → docker compose pull → up → healthcheck

**Step 2: 创建 renovate-deploy.yml**

Renovate PR merged → 自动触发部署

**Step 3: Commit**

---

## Task 5: 项目模板文件 — 脚本

**Objective:** 创建 deploy.sh, rollback.sh, pre-deploy-check.sh 模板

**Files:**
- Create: `templates/deploy.sh`
- Create: `templates/rollback.sh`
- Create: `templates/pre-deploy-check.sh`

**Step 1: 创建 deploy.sh**

Colima 感知 + Clash 检查 + PT 保护 + 通知

**Step 2: 创建 rollback.sh**

4 级回滚：单服务 / Git / PG / Colima

**Step 3: 创建 pre-deploy-check.sh**

磁盘 + 内存 + Colima + Transmission + Clash 检查

**Step 4: Commit**

---

## Task 6: 项目模板文件 — Hermes 集成

**Objective:** 创建 .hermes/ 目录下的脚本和 cron job 模板

**Files:**
- Create: `templates/.hermes/scripts/health-check.sh`
- Create: `templates/.hermes/scripts/notify.sh`
- Create: `templates/.hermes/scripts/backup.sh`
- Create: `templates/.hermes/cron/health-monitor.md`
- Create: `templates/.hermes/cron/backup.md`

**Step 1: 创建脚本模板**
**Step 2: 创建 cron job 配置模板**
**Step 3: Commit**

---

## Task 7: 项目模板文件 — 文档模板

**Objective:** 创建 docs/ 和 tests/ 下的模板文件

**Files:**
- Create: `templates/docs/spec.md`
- Create: `templates/docs/prompt_plan.md`
- Create: `templates/docs/todo.md`
- Create: `templates/tests/smoke-test.sh`
- Create: `templates/tests/integration-test.sh`
- Create: `templates/renovate.json`
- Create: `templates/README.md`

**Step 1: 逐个创建模板**
**Step 2: Commit**

---

## Task 8: Shell CLI — install.sh

**Objective:** 创建 Shell 安装脚本 + init 命令

**Files:**
- Create: `cli/shell/install.sh`
- Create: `cli/shell/init.sh`

**Step 1: 创建 install.sh**

下载模板文件 → 复制到目标目录 → 替换占位符

**Step 2: 创建 init.sh**

交互式/命令式双模式

**Step 3: 测试**

```bash
bash cli/shell/init.sh test-project --port 8080
ls -la test-project/
```

**Step 4: Commit**

---

## Task 9: Node.js CLI — create-hawk-homelab

**Objective:** 创建 npm 包

**Files:**
- Create: `cli/nodejs/package.json`
- Create: `cli/nodejs/bin/create-hawk-homelab.js`
- Create: `cli/nodejs/lib/init.js`

**Step 1: 创建 package.json**
**Step 2: 创建 CLI 入口**
**Step 3: 创建初始化逻辑**
**Step 4: 测试**

```bash
cd cli/nodejs && node bin/create-hawk-homelab.js test-project
```

**Step 5: Commit**

---

## Task 10: Python CLI — hawk-homelab

**Objective:** 创建 pipx 可安装的 Python 包

**Files:**
- Create: `cli/python/pyproject.toml`
- Create: `cli/python/hawk_homelab/__init__.py`
- Create: `cli/python/hawk_homelab/cli.py`
- Create: `cli/python/hawk_homelab/init.py`

**Step 1: 创建 pyproject.toml**
**Step 2: 创建 CLI 入口**
**Step 3: 创建初始化逻辑**
**Step 4: 测试**

```bash
cd cli/python && pip install -e . && hawk-homelab init test-project
```

**Step 5: Commit**

---

## Task 11: Hermes Skill — create-hawk-homelab

**Objective:** 创建 Hermes Skill，封装 CLI 调用

**Files:**
- Create: Skill `create-hawk-homelab` via `skill_manage`

**Step 1: 创建 Skill**

触发词、CLI 调用逻辑、结果解析

**Step 2: 验证**

Hermes 说 "初始化 homelab 项目 test-app" → Skill 自动执行

**Step 3: Commit**

---

## Task 12: 文档补充

**Objective:** 补充 FAQ 和多项目管理规范

**Files:**
- Create: `docs/faq.md`
- Create: `docs/multi-project.md`

**Step 1: FAQ — 从实际踩坑中提炼**
**Step 2: 多项目规范 — /opt/stacks/ 目录结构**
**Step 3: Commit**

---

## Task 13: 端到端测试

**Objective:** 用脚手架生成一个真实项目，验证全流程

**Step 1: 用 CLI 生成项目**

```bash
hawk-homelab init test-app --port 3333 --services web,postgres
```

**Step 2: 验证生成的文件完整性**
**Step 3: 验证 deploy.sh 能执行（dry-run）**
**Step 4: 验证 CLAUDE.md 含正确环境约束**
**Step 5: Commit 测试结果**

---

## 执行顺序

```
Task 1-7 (模板文件) → Task 8 (Shell CLI) → Task 11 (Skill)
                                    ↓
                        Task 9 (Node.js) → Task 10 (Python)
                                    ↓
                        Task 12 (文档) → Task 13 (E2E 测试)
```

模板文件是基础，先全部完成。CLI 可以并行开发。Skill 依赖至少一个 CLI。最后 E2E 测试。
