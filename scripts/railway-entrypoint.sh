#!/bin/sh
# Railway entrypoint for OpenClaw gateway.
#
# Vì sao tồn tại: `openclaw config set ...` phụ thuộc cú pháp/phiên bản CLI của
# image đã release và có thể thất bại âm thầm. Script này ghi THẲNG vào đúng
# file config mà gateway sẽ đọc (OPENCLAW_CONFIG_PATH), nên không phụ thuộc CLI.
#
# Ghi 2 thứ vào gateway.controlUi (merge, idempotent, không clobber key khác):
#   1. allowedOrigins  <- CONTROL_UI_ORIGIN   (fix lỗi "origin not allowed")
#   2. dangerouslyDisableDeviceAuth: true      (bỏ ghép thiết bị; chỉ cần token)
#      -> tắt bằng cách set CONTROL_UI_DISABLE_DEVICE_AUTH=0 (hoặc false/no).
#
# An toàn: vẫn yêu cầu token Gateway (OPENCLAW_GATEWAY_TOKEN) để vào Control UI.
# Lỗi merge KHÔNG chặn gateway khởi động.
set -e

CFG="${OPENCLAW_CONFIG_PATH:-/home/node/.openclaw/openclaw.json}"

if [ -n "$CONTROL_UI_ORIGIN" ]; then
  mkdir -p "$(dirname "$CFG")"
  OPENCLAW_CONFIG_PATH="$CFG" node <<'NODE' || echo "[railway-entrypoint] config merge failed (non-fatal), continuing"
const fs = require("fs");
const p = process.env.OPENCLAW_CONFIG_PATH;
const origin = process.env.CONTROL_UI_ORIGIN;
const disableRaw = (process.env.CONTROL_UI_DISABLE_DEVICE_AUTH || "").trim().toLowerCase();
const disableDeviceAuth = !["0", "false", "no", "off"].includes(disableRaw); // default: true
let cfg = {};
try { cfg = JSON.parse(fs.readFileSync(p, "utf8")) || {}; } catch (_) {}
cfg.gateway = cfg.gateway || {};
cfg.gateway.controlUi = cfg.gateway.controlUi || {};
const cur = Array.isArray(cfg.gateway.controlUi.allowedOrigins)
  ? cfg.gateway.controlUi.allowedOrigins
  : [];
if (origin && !cur.includes(origin)) cur.push(origin);
cfg.gateway.controlUi.allowedOrigins = cur;
cfg.gateway.controlUi.dangerouslyDisableDeviceAuth = disableDeviceAuth;
fs.writeFileSync(p, JSON.stringify(cfg, null, 2));
console.log(
  "[railway-entrypoint] " + p +
  " allowedOrigins=" + JSON.stringify(cur) +
  " dangerouslyDisableDeviceAuth=" + disableDeviceAuth,
);
NODE
fi

exec node /app/openclaw.mjs gateway --bind lan --port 8080 --allow-unconfigured
