# Backup Schedule — test-python-project

## 触发配置

- **频率**: 每天凌晨 3:00 (cron: `0 3 * * *`)
- **脚本**: `.hermes/scripts/backup.sh`
- **超时**: 300 秒

## 备份内容

| 类型 | 来源 | 目标 |
|------|------|------|
| PostgreSQL | `hawk-postgres` 容器 | `backups/pg_backup_YYYYMMDD_HHMMSS.sql` |
| Volume | `test-python-project-data` | `backups/volume_test-python-project_YYYYMMDD_HHMMSS.tar.gz` |

## 保留策略

- **保留天数**: 7 天
- **清理**: 自动删除超过保留期的备份文件

## 恢复流程

```bash
# PostgreSQL 恢复
docker exec -i hawk-postgres psql -U {{DB_USER}} < backups/pg_backup_XXXXXXXX.sql

# Volume 恢复
docker run --rm -v test-python-project-data:/target -v $(pwd)/backups:/backup \
    alpine tar xzf /backup/volume_test-python-project_XXXXXXXX.tar.gz -C /target
```

## 注意事项

- 备份期间服务正常运行（pg_dump 是在线备份）
- 备份文件不提交到 Git（已在 .gitignore 中排除 backups/）
- 建议定期将备份同步到外部存储
