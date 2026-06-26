#!/bin/bash
set -e

echo "=================================================="
echo "🚀 BẮT ĐẦU SETUP CLI PROXY API + MANAGEMENT CENTER"
echo "=================================================="

# 1. Cập nhật hệ thống
echo "🔄 Đang cập nhật Ubuntu..."
sudo apt update && sudo apt upgrade -y

# 2. Cài đặt CLI Proxy API
echo "📥 Đang cài CLI Proxy API + WebUI Management Center..."
curl -fsSL https://raw.githubusercontent.com/brokechubb/cliproxyapi-installer/refs/heads/master/cliproxyapi-installer | bash

# Kiểm tra binary tồn tại
if [ ! -f "$HOME/cliproxyapi/cli-proxy-api" ]; then
  echo "❌ Cài đặt thất bại! Binary không tìm thấy tại ~/cliproxyapi/cli-proxy-api"
  exit 1
fi
echo "✅ Binary đã cài xong."

# 3. Vào thư mục và cấu hình
cd ~/cliproxyapi

echo "🔧 Đang cấu hình remote management + API key..."

# === Đặt Management Key và API Key cố định ===
SECRET_KEY="admin123"
API_KEY="Bac12345@"

# Sửa API key trong config
sed -i 's/^api-keys:/api-keys:/' config.yaml
# Xóa tất cả api-keys cũ và thay bằng key mới
sed -i '/^api-keys:/,/^[^ ]/{/^api-keys:/!{/^  - /d}}' config.yaml
sed -i "/^api-keys:/a\\  - \"${API_KEY}\"" config.yaml

# Xóa block remote-management cũ nếu có
sed -i '/^# =.*REMOTE MANAGEMENT/d' config.yaml 2>/dev/null || true
sed -i '/^remote-management:/,/^[^ ]/{ /^[^ ]/!d; /^remote-management:/d }' config.yaml 2>/dev/null || true

# Thêm block remote-management
cat >> config.yaml << EOF

# ====================== REMOTE MANAGEMENT ======================
remote-management:
  allow-remote: true
  secret-key: "${SECRET_KEY}"
  disable-control-panel: false
EOF

# Xác nhận config
echo "📋 Kiểm tra config:"
grep -A4 "remote-management:" config.yaml
echo "---"
grep -A2 "api-keys:" config.yaml

echo "✅ Management Key: $SECRET_KEY"
echo "✅ API Key: $API_KEY"

# 4. Tạo systemd user service nếu chưa có
SERVICE_FILE="$HOME/.config/systemd/user/cliproxyapi.service"
if [ ! -f "$SERVICE_FILE" ]; then
  echo "⚙️ Tạo systemd service..."
  mkdir -p ~/.config/systemd/user
  cat > "$SERVICE_FILE" << EOF
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
EOF
fi

# 5. Mở firewall
echo "🔓 Mở port 8317..."
sudo ufw allow 8317/tcp
sudo ufw reload

# 6. Khởi động service
echo "▶️ Khởi động CLI Proxy API service..."
systemctl --user daemon-reload
systemctl --user enable cliproxyapi.service
systemctl --user restart cliproxyapi.service

# 7. Kiểm tra service
sleep 4
echo "📊 Trạng thái service:"
systemctl --user status cliproxyapi.service --no-pager | head -n 15

# Kiểm tra port
echo "🔌 Kiểm tra port 8317:"
ss -tlnp | grep 8317 && echo "✅ Port OK" || echo "⚠️ Port chưa mở!"

# 8. Lấy IP public
IP=$(curl -s ifconfig.me)

echo ""
echo "🎉 SETUP HOÀN TẤT 100%!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📍 Link WebUI Management Center:"
echo "   http://$IP:8317/management.html"
echo ""
echo "🔑 Management Key:"
echo "   $SECRET_KEY"
echo ""
echo "🔑 API Key (dùng cho OpenAI-compatible endpoint):"
echo "   $API_KEY"
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
