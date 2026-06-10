#!/bin/sh
# Railway entrypoint for OpenClaw gateway.
#
# Vì sao tồn tại: `openclaw config set ...` phụ thuộc cú pháp/phiên bản CLI của
# image đã release và có thể thất bại âm thầm. Script này ghi THẲNG vào đúng
# file config mà gateway sẽ đọc (OPENCLAW_CONFIG_PATH), nên không phụ thuộc CLI.
#
# - Chỉ chạy khi CONTROL_UI_ORIGIN được set.
# - Merge (không clobber config khác), idempotent (không thêm trùng origin).
# - Lỗi merge KHÔNG chặn gateway khởi động (|| echo + không set -e quanh exec).
set -e

CFG="${OPENCLAW_CONFIG_PATH:-/home/node/.openclaw/openclaw.json}"

if [ -n "$CONTROL_UI_ORIGIN" ]; then
  mkdir -p "$(dirname "$CFG")"
  OPENCLAW_CONFIG_PATH="$CFG" node <<'NODE' || echo "[railway-entrypoint] config merge failed (non-fatal), continuing"
const fs = require("fs");
const p = process.env.OPENCLAW_CONFIG_PATH;
const origin = process.env.CONTROL_UI_ORIGIN;
let cfg = {};
try { cfg = JSON.parse(fs.readFileSync(p, "utf8")) || {}; } catch (_) {}
cfg.gateway = cfg.gateway || {};
cfg.gateway.controlUi = cfg.gateway.controlUi || {};
const cur = Array.isArray(cfg.gateway.controlUi.allowedOrigins)
  ? cfg.gateway.controlUi.allowedOrigins
  : [];
if (!cur.includes(origin)) cur.push(origin);
cfg.gateway.controlUi.allowedOrigins = cur;
fs.writeFileSync(p, JSON.stringify(cfg, null, 2));
console.log("[railway-entrypoint] allowedOrigins in " + p + " = " + JSON.stringify(cur));
NODE
fi

exec node /app/openclaw.mjs gateway --bind lan --port 8080 --allow-unconfigured
