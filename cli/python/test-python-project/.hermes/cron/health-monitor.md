# Health Monitor — test-python-project

## 触发配置

- **频率**: 每 5 分钟
- **脚本**: `.hermes/scripts/health-check.sh`
- **超时**: 30 秒

## 执行逻辑

1. 检查 `hawk-test-python-project` 容器状态
2. HTTP 请求 `http://localhost:5555/health`
3. 失败时重试 3 次，间隔 10 秒
4. 持续失败则通过 notify.sh 发送告警

## 告警规则

| 条件 | 级别 | 动作 |
|------|------|------|
| 容器停止 | critical | 立即通知 + 尝试重启 |
| 健康检查超时 | warning | 通知 + 继续监控 |
| 连续 3 次失败 | critical | 通知 + 触发回滚 |

## 静默时段

- 无 (7x24 监控)
- 但通知可通过 notify.sh 的 webhook 配置控制
