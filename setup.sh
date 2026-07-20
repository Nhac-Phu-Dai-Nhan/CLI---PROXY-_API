#!/bin/bash
set -e
echo "=================================================="
echo "🚀 BẮT ĐẦU SETUP CLI PROXY API + MANAGEMENT CENTER"
echo "=================================================="

SECRET_KEY="admin123"
API_KEY="admin123"

# 1. Cập nhật hệ thống
echo "🔄 Đang cập nhật Ubuntu..."
apt update && apt upgrade -y

# 2. Cài đặt CLI Proxy API
echo "📥 Đang cài CLI Proxy API + WebUI Management Center..."
curl -fsSL https://raw.githubusercontent.com/brokechubb/cliproxyapi-installer/refs/heads/master/cliproxyapi-installer | bash

if [ ! -f "$HOME/cliproxyapi/cli-proxy-api" ]; then
  echo "❌ Cài đặt thất bại! Binary không tìm thấy tại ~/cliproxyapi/cli-proxy-api"
  exit 1
fi
echo "✅ Binary đã cài xong."

cd ~/cliproxyapi
echo "🔧 Đang cấu hình remote management + API key..."

# Backup config trước khi sửa
cp config.yaml config.yaml.bak.$(date +%s)

# Xóa toàn bộ api-keys cũ, thêm key mới
awk '
/^api-keys:/ { print; in_block=1; next }
in_block && /^  - / { next }
{ in_block=0; print }
' config.yaml > config.yaml.tmp && mv config.yaml.tmp config.yaml
sed -i "/^api-keys:/a\\  - \"${API_KEY}\"" config.yaml

# Xóa block remote-management cũ, thêm block mới
awk '
/^# =+.*REMOTE MANAGEMENT/ { skip=1; next }
/^remote-management:/ { skip=1; next }
skip && /^  / { next }
{ skip=0; print }
' config.yaml > config.yaml.tmp && mv config.yaml.tmp config.yaml

cat >> config.yaml << CFGEOF
# ====================== REMOTE MANAGEMENT ======================
remote-management:
  allow-remote: true
  secret-key: "${SECRET_KEY}"
  disable-control-panel: false
CFGEOF

echo "📋 Kiểm tra config:"
grep -A4 "remote-management:" config.yaml
echo "---"
grep -A2 "api-keys:" config.yaml
echo "✅ Management Key: $SECRET_KEY"
echo "✅ API Key: $API_KEY"

# 3. systemd user service (installer đã tạo sẵn, đảm bảo tồn tại)
SERVICE_FILE="$HOME/.config/systemd/user/cliproxyapi.service"
if [ ! -f "$SERVICE_FILE" ]; then
  echo "⚙️ Tạo systemd service..."
  mkdir -p ~/.config/systemd/user
  cat > "$SERVICE_FILE" << SVCEOF
[Unit]
Description=CLI Proxy API Service
After=network.target

[Service]
Type=simple
WorkingDirectory=${HOME}/cliproxyapi
ExecStart=${HOME}/cliproxyapi/cli-proxy-api
Restart=always
RestartSec=5

[Install]
WantedBy=default.target
SVCEOF
fi

# 4. Mở firewall (ufw nếu có, fallback iptables)
echo "🔓 Mở port 8317..."
if command -v ufw >/dev/null 2>&1; then
  ufw allow 8317/tcp
  if ! ufw status | grep -q "Status: active"; then
    ufw --force enable
  fi
  ufw reload
else
  echo "ℹ️ Không có ufw, dùng iptables..."
  iptables -I INPUT -p tcp --dport 8317 -j ACCEPT
  DEBIAN_FRONTEND=noninteractive apt install -y iptables-persistent 2>/dev/null || true
  netfilter-persistent save 2>/dev/null || true
fi

# 5. Bật linger để service sống sau khi logout SSH
loginctl enable-linger root 2>/dev/null || loginctl enable-linger "$(whoami)" 2>/dev/null || true

# 6. Khởi động service
echo "▶️ Khởi động CLI Proxy API service..."
systemctl --user daemon-reload
systemctl --user enable cliproxyapi.service
systemctl --user restart cliproxyapi.service

# 7. Kiểm tra
sleep 4
echo "📊 Trạng thái service:"
systemctl --user status cliproxyapi.service --no-pager | head -n 15

echo "🔌 Kiểm tra port 8317:"
ss -tlnp | grep 8317 && echo "✅ Port OK" || echo "⚠️ Port chưa mở!"

IP=$(curl -s ifconfig.me)
echo ""
echo "🎉 SETUP HOÀN TẤT 100%!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📍 Link WebUI Management Center:"
echo "   http://$IP:8317/management.html"
echo ""
echo "🔑 Management Key: $SECRET_KEY"
echo "🔑 API Key: $API_KEY"
echo ""
echo "📌 Hướng dẫn:"
echo "   1. Mở link trên bằng Chrome/Firefox"
echo "   2. Dán Management Key vào ô và nhấn Login"
echo "   3. Vào OAuth để login Gemini / Claude / Grok..."
echo ""
echo "🔄 Lệnh quản lý:"
echo "   systemctl --user status cliproxyapi.service"
echo "   systemctl --user restart cliproxyapi.service"
echo "   journalctl --user -u cliproxyapi.service -f"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
