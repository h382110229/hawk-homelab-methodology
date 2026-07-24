# test-python-project

> A homelab service managed by Hawk methodology
> Deployed on Mac Pro 6,1 (2013) Homelab

## Quick Start

```bash
# 本地开发
docker compose up -d
curl http://localhost:5555/health

# 部署到 Mac Pro
bash pre-deploy-check.sh
bash deploy.sh
```

## Architecture

| 组件 | 技术 |
|------|------|
| 容器运行时 | Colima (QEMU x86_64) |
| 反向代理 | Cloudflare Tunnel |
| 网络 | Clash Verge TUN |
| CI/CD | GitHub Actions → SSH |

## Services

| 服务 | 端口 | 说明 |
|------|------|------|
| test-python-project | 5555 | A homelab service managed by Hawk methodology |

## Deployment

```bash
# 前置检查
bash pre-deploy-check.sh

# 部署 (含健康检查 + 自动回滚)
bash deploy.sh

# 回滚 (4 级)
bash rollback.sh service   # Level 1: 服务级
bash rollback.sh git       # Level 2: Git 级
bash rollback.sh pg        # Level 3: 数据库级
bash rollback.sh colima    # Level 4: Colima 重启 (最后手段)
```

## Testing

```bash
# 冒烟测试
bash tests/smoke-test.sh

# 集成测试
bash tests/integration-test.sh
```

## Monitoring

- 健康检查: `.hermes/scripts/health-check.sh`
- 备份: `.hermes/scripts/backup.sh`
- 通知: `.hermes/scripts/notify.sh`

## Environment Variables

| 变量 | 说明 | 默认值 |
|------|------|--------|
| `{{VAR_1}}` | `{{VAR_DESC}}` | `{{DEFAULT}}` |

## Tech Stack

- {{TECH_STACK}}

## License

{{LICENSE}}
