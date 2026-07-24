#!/usr/bin/env bash
# notify.sh — 通知脚本 (飞书 / QQ / 自定义 Webhook)
# 用法: notify.sh <status> <message>
# status: success | failure | warning | critical
set -euo pipefail

STATUS="${1:-info}"
MESSAGE="${2:-No message}"
PROJECT_NAME="test-python-project"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

# ============================================================
# 颜色 Emoji
# ============================================================
case "$STATUS" in
    success)  EMOJI="✅" ;;
    failure)  EMOJI="❌" ;;
    warning)  EMOJI="⚠️" ;;
    critical) EMOJI="🚨" ;;
    *)        EMOJI="ℹ️" ;;
esac

FULL_MESSAGE="${EMOJI} [${PROJECT_NAME}] ${STATUS^^}: ${MESSAGE} (${TIMESTAMP})"

# ============================================================
# 控制台输出
# ============================================================
echo "$FULL_MESSAGE"

# ============================================================
# Webhook 通知 (取消注释并配置)
# ============================================================

# --- 飞书 (Feishu) ---
# FEISHU_WEBHOOK="{{FEISHU_WEBHOOK_URL}}"
# if [ -n "$FEISHU_WEBHOOK" ]; then
#     curl -sf -X POST "$FEISHU_WEBHOOK" \
#         -H "Content-Type: application/json" \
#         -d "{
#             \"msg_type\": \"text\",
#             \"content\": {
#                 \"text\": \"$FULL_MESSAGE\"
#             }
#         }" > /dev/null 2>&1
#     echo "Notified via Feishu"
# fi

# --- QQ (通过 napcat / go-cqhttp) ---
# QQ_WEBHOOK="{{QQ_WEBHOOK_URL}}"
# QQ_GROUP_ID="{{QQ_GROUP_ID}}"
# if [ -n "$QQ_WEBHOOK" ]; then
#     curl -sf -X POST "$QQ_WEBHOOK/send_group_msg" \
#         -H "Content-Type: application/json" \
#         -d "{
#             \"group_id\": $QQ_GROUP_ID,
#             \"message\": \"$FULL_MESSAGE\"
#         }" > /dev/null 2>&1
#     echo "Notified via QQ"
# fi

# --- Telegram ---
# TELEGRAM_BOT_TOKEN="{{TELEGRAM_BOT_TOKEN}}"
# TELEGRAM_CHAT_ID="{{TELEGRAM_CHAT_ID}}"
# if [ -n "$TELEGRAM_BOT_TOKEN" ]; then
#     curl -sf -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
#         -H "Content-Type: application/json" \
#         -d "{
#             \"chat_id\": \"$TELEGRAM_CHAT_ID\",
#             \"text\": \"$FULL_MESSAGE\",
#             \"parse_mode\": \"HTML\"
#         }" > /dev/null 2>&1
#     echo "Notified via Telegram"
# fi

# --- 自定义 Webhook ---
# CUSTOM_WEBHOOK="{{CUSTOM_WEBHOOK_URL}}"
# if [ -n "$CUSTOM_WEBHOOK" ]; then
#     curl -sf -X POST "$CUSTOM_WEBHOOK" \
#         -H "Content-Type: application/json" \
#         -d "{\"project\": \"$PROJECT_NAME\", \"status\": \"$STATUS\", \"message\": \"$MESSAGE\"}" \
#         > /dev/null 2>&1
#     echo "Notified via custom webhook"
# fi
