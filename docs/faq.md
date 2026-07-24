# hawk-homelab FAQ — Common Pitfalls

> Real-world issues encountered on Mac Pro 6,1 (2013) / macOS 12.7.6 / Colima homelab.

---

## Q1: Why should I NEVER use `colima restart`?

**A:** `colima restart` stops the entire VM, killing **all** running containers — including Transmission (PT seeding), Cloudflare Tunnel, and every other service. Instead, restart only the target service:

```bash
# ✅ Correct — only restarts the target service
export DOCKER_HOST=unix:///Users/huoke/.colima/docker.sock
docker compose up -d --no-deps --force-recreate <service-name>

# ❌ NEVER do this
colima restart
```

If Colima itself is broken, use `colima stop && colima start` only as a last resort, and be prepared to manually restart all services afterward (see `rollback.sh` Level 4).

---

## Q2: Docker image pulls are failing — Clash TUN is intercepting them?

**A:** Clash Verge TUN mode intercepts all traffic, including Docker Hub requests. Ensure your Clash Merge Profile has a DIRECT rule for Docker registries:

```yaml
# In Clash config / Merge Profile:
rules:
  - DOMAIN-SUFFIX,docker.io,DIRECT
  - DOMAIN-SUFFIX,docker.com,DIRECT
  - DOMAIN-SUFFIX,ghcr.io,DIRECT
  - DOMAIN-SUFFIX,registry.npmjs.org,DIRECT
  - DOMAIN-SUFFIX,pypi.org,DIRECT
```

After updating, restart Clash Verge and verify: `curl -I https://registry-1.docker.io/v2/`

---

## Q3: My PT seeding got interrupted during deployment. How do I prevent this?

**A:** Transmission must run 24/7 — it is a core service on the homelab. The deployment scripts are designed to protect it:

1. **Always use `--no-deps`**: `docker compose up -d --no-deps <service>` — only restarts the target.
2. **Never use `colima restart`** (see Q1).
3. **Run `pre-deploy-check.sh`** before deploying — it verifies Transmission is running.
4. **Use the `hawk-transmission` container name** to check status: `docker ps | grep hawk-transmission`.

If Transmission does get interrupted, restart it immediately:
```bash
cd /opt/stacks/transmission && docker compose up -d
```

---

## Q4: New files on the host don't appear inside the Colima VM. Why?

**A:** Colima uses sshfs to mount the home directory into the VM, which has sync latency and may miss newly created files. **Use Docker named volumes instead of bind mounts** for data:

```yaml
# ✅ Use named volumes (reliable)
volumes:
  - my-project-data:/data

# ⚠️ Bind mounts may have sync issues
volumes:
  - /Users/huoke/some-path:/data
```

If you must use bind mounts and files aren't showing up, restart the Colima mount:
```bash
colima ssh -- sudo mount -o remount /Users/huoke
```

---

## Q5: Port 52888 (Colima SSH) is not accessible after restart. How do I fix it?

**A:** Colima's SSH forwarder binds to IPv4 only (`127.0.0.1`), but macOS may resolve `localhost` to IPv6 first. Verify and fix:

```bash
# Check if the port is actually listening on IPv4
lsof -i :52888 | grep LISTEN

# If missing, restart Colima SSH forwarding
colima stop && colima start

# Verify Docker socket is accessible
docker info
```

If the socket itself is missing: `ls -la ~/.colima/docker.sock`. The socket path should be `unix:///Users/huoke/.colima/docker.sock`.

---

## Q6: Homebrew install fails on macOS 12.7.6. What's wrong?

**A:** macOS 12 (Monterey) is Tier 3 for Homebrew — many formulae have no pre-compiled bottles, so builds from source often fail with outdated Xcode toolchain errors. **Prefer Docker over host installs**:

```bash
# ✅ Run tools in Docker instead of installing on host
docker run --rm -v $(pwd):/app -w /app node:18 npm install
docker run --rm -v $(pwd):/app -w /app python:3.11 pip install -r requirements.txt

# ⚠️ If you must install on host, pin to older versions
brew install node@18  # LTS, more likely to have a bottle
```

If a bottle is missing and source build fails, check if a Docker image already provides the tool.

---

## Q7: How do I manage Cloudflare Tunnel as a Docker container?

**A:** On this homelab, Cloudflare Tunnel runs as a Docker container (`hawk-cloudflared`), not as a host systemd service. Manage it with Docker commands:

```bash
# Check tunnel status
docker ps | grep hawk-cloudflared

# View tunnel logs
docker logs hawk-cloudflared --tail 50

# Restart tunnel (safe — does not affect other services)
docker restart hawk-cloudflared

# The tunnel config is in /opt/stacks/cloudflared/
cd /opt/stacks/cloudflared && docker compose up -d
```

Never use `systemctl` or `launchctl` for the tunnel — it's containerized.

---

## Q8: Template placeholders `{{}}` break the YAML parser. How do I use templates?

**A:** The `{{PROJECT_NAME}}` style placeholders are **not valid YAML** — they exist only in template files. The CLI replaces all placeholders before writing the final files:

```bash
# The init.sh script does this automatically:
bash cli/shell/init.sh my-app --port 8080 --image nginx --version 1.25

# It copies templates/ → my-app/ and runs perl -pi -e to replace:
#   {{PROJECT_NAME}} → my-app
#   {{PORT}} → 8080
#   {{IMAGE}} → nginx
#   {{VERSION}} → 1.25
#   {{DATE}} → 2026-07-24
```

**Never** edit template files directly and try to parse them with `docker compose config` — replace placeholders first. If you see `{{}}` in a deployed file, the CLI replacement failed.

---

## Q9: `pip install hawk-homelab` fails on macOS 12. What's the workaround?

**A:** macOS 12 ships with an older `setuptools` that may not support modern `pyproject.toml`. Use the module invocation directly:

```bash
# Option 1: Run as a module (always works)
python3 -m hawk_homelab.cli init my-project --port 8080

# Option 2: Use pipx (isolated environment, avoids setuptools issues)
pipx install hawk-homelab
hawk-homelab init my-project --port 8080

# Option 3: Use the Shell CLI instead (zero dependencies)
bash cli/shell/init.sh my-project --port 8080
```

The Shell CLI (`init.sh`) is the recommended approach on macOS 12 since it has zero Python/Node.js dependencies.
