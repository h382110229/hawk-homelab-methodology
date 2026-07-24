# hawk-homelab-methodology — 人工检查清单

## 模板文件
- [ ] docker-compose.yml 含 healthcheck
- [ ] CLAUDE.md 含 Colima/Clash/CF Tunnel 约束
- [ ] deploy-safety.md 规则完整
- [ ] GitHub Actions SSH 到 Mac Pro 可执行
- [ ] renovate.json 排除 Postgres major
- [ ] 所有脚本有 `set -euo pipefail`

## CLI 工具
- [ ] Shell CLI: `init.sh test-app` 生成完整目录
- [ ] Node.js CLI: `npx create-hawk-homelab test-app` 可执行
- [ ] Python CLI: `hawk-homelab init test-app` 可执行
- [ ] 三种 CLI 生成物完全一致

## Hermes Skill
- [ ] 触发词 "初始化 homelab 项目" 能命中
- [ ] 交互式模式：缺参数时反问
- [ ] 命令式模式：有参数直接执行
- [ ] 生成结果返回给用户

## 端到端
- [ ] 生成的项目 deploy.sh --dry-run 通过
- [ ] 生成的 CLAUDE.md 被 Claude Code 正确加载
- [ ] 生成的 GitHub Actions YAML 语法正确
- [ ] 生成的 renovate.json 格式正确
