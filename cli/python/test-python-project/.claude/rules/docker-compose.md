# Docker Compose 规则

> Mac Pro 2013 Homelab Docker Compose 编写规范

## 强制规则

### 镜像标签

- **必须** 指定版本标签: `image: nginx:1.25-alpine`
- **禁止** `:latest` 标签
- Postgres 必须指定主版本: `postgres:16.3`
- 理由: 部署可重现性 + 安全审计 + 回滚能力

### 命名规范

- container_name: `hawk-{服务名}` (如 `hawk-nginx`)
- volume: `{服务名}-data`
- network: 统一使用外部网络 `app-net`

### 健康检查

- 每个服务**必须**配置 healthcheck
- 使用 curl 检查 `/health` 端点
- 配置模板:
  ```yaml
  healthcheck:
    test: ["CMD", "curl", "-f", "http://localhost:8080/health"]
    interval: 30s
    timeout: 10s
    retries: 3
    start_period: 10s
  ```

### 网络

- 所有服务加入 `app-net` 外部网络
- 不要创建服务专属网络

### 重启策略

- 所有服务使用 `restart: unless-stopped`
- 不要用 `always` — 避免 Colima 重启时的竞态条件

### 环境变量

- 设置 `TZ=Asia/Shanghai`
- 敏感信息使用 `.env` 文件，不提交到 Git

## Colima 特殊处理

```yaml
# 不需要额外配置，但要知道:
# - DOCKER_HOST=unix:///Users/huoke/.colima/docker.sock
# - 架构: x86_64 (QEMU emulation)
# - 内存有限，避免单容器占用 > 4GB
```

## 完整模板

```yaml
services:
  test-python-project:
    image: nginx:1.25
    container_name: hawk-test-python-project
    restart: unless-stopped
    ports:
      - "5555:8080"
    volumes:
      - test-python-project-data:/data
    networks:
      - app-net
    environment:
      - TZ=Asia/Shanghai
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 10s
    labels:
      - "hawk.project=test-python-project"
      - "hawk.managed=true"

volumes:
  test-python-project-data:

networks:
  app-net:
    external: true
```
