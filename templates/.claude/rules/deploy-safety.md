# 部署安全规则

> Mac Pro 2013 Homelab 部署安全约束 — 违反任何一条都可能造成数据丢失

## 绝对禁止

### ❌ 禁止 colima restart

```bash
# 这些命令会中断所有容器，包括 Transmission
colima restart          # ❌ 禁止
colima stop && colima start  # ❌ 禁止
```

**原因**: Colima restart 会重启 Docker daemon，导致所有容器停止。Transmission 中断意味着 PT 下载丢失、可能被 tracker 惩罚。

### ❌ 禁止停止 Transmission

```bash
docker stop hawk-transmission    # ❌ 禁止
docker restart hawk-transmission # ❌ 禁止
```

### ❌ 禁止 docker compose down（无项目限定）

```bash
docker compose down              # ❌ 禁止 — 影响所有服务
docker compose -p xxx down       # ❌ 禁止 — 同上
```

### ❌ 禁止删除共享 Volume

```bash
docker volume prune              # ❌ 可能删除 PT 数据
```

## 强制流程

### ✅ 部署前必须检查

```bash
bash pre-deploy-check.sh
# 检查: 磁盘空间、内存、Colima 状态、Transmission 状态、Clash 状态
```

### ✅ 部署必须使用 --no-deps

```bash
# 正确: 只操作目标服务
docker compose up -d --no-deps {{PROJECT_NAME}}

# 错误: 影响所有服务
docker compose up -d
```

### ✅ 部署失败必须回滚

```bash
# 部署脚本内置回滚逻辑
bash deploy.sh
# 如果 healthcheck 失败，自动回滚到上一版本
```

### ✅ 数据库变更前必须备份

```bash
# 备份 PostgreSQL
docker exec hawk-postgres pg_dumpall -U {{DB_USER}} > backup_$(date +%Y%m%d_%H%M%S).sql
```

## 回滚策略

| 级别 | 操作 | 影响范围 |
|------|------|---------|
| 1. 服务级 | `docker compose up -d --no-deps` 回退镜像版本 | 单个服务 |
| 2. Git 级 | `git revert HEAD && deploy` | 代码回退 |
| 3. 数据库级 | 恢复 pg_dump 备份 | 数据回退 |
| 4. Colima 级 | `colima stop && colima start` | **最后手段，中断一切** |

## 部署检查清单

- [ ] 运行 `pre-deploy-check.sh` 通过
- [ ] 镜像版本已锁定（非 `:latest`）
- [ ] 无 Postgres major 版本升级（除非人工审批）
- [ ] Transmission 状态正常（seed 活跃）
- [ ] Clash Verge TUN 正常运行
- [ ] Cloudflare Tunnel 连接正常
- [ ] 备份已完成（如有 DB 变更）
