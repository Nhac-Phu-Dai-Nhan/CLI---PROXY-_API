#!/bin/bash
set -e

echo "=================================================="
echo "🚀 BẮT ĐẦU SETUP CLI PROXY API + MANAGEMENT CENTER"
echo "=================================================="

# 1. Cập nhật hệ thống
echo "🔄 Đang cập nhật Ubuntu..."
sudo apt update && sudo apt upgrade -y

# 2. Cài đặt CLI Proxy API (phiên bản mới nhất)
echo "📥 Đang cài CLI Proxy API + WebUI Management Center..."
curl -fsSL https://raw.githubusercontent.com/brokechubb/cliproxyapi-installer/refs/heads/master/cliproxyapi-installer | bash

# 3. Vào thư mục và cấu hình remote management
cd ~/cliproxyapi

echo "🔧 Đang cấu hình remote management + tạo Management Key mạnh..."
# Tạo secret-key ngẫu nhiên 32 ký tự
SECRET_KEY=$(openssl rand -hex 16 | tr '[:lower:]' '[:upper:]')

# Xóa sạch phần remote-management cũ (nếu có) để tránh duplicate
sed -i '/remote-management:/,/^$/d' config.yaml 2>/dev/null || true

# Thêm phần remote-management chuẩn
cat >> config.yaml << EOF

# ====================== REMOTE MANAGEMENT ======================
remote-management:
  # Cho phép quản lý từ xa (rất quan trọng)
  allow-remote: true
  # Management Key (bắt buộc để mở WebUI)
  secret-key: "$SECRET_KEY"
  # Không tắt control panel
  disable-control-panel: false
EOF

echo "✅ Management Key đã tạo: $SECRET_KEY"

# 4. Mở firewall
echo "🔓 Mở port 8317..."
sudo ufw allow 8317/tcp
sudo ufw reload

# 5. Khởi động service
echo "▶️ Khởi động CLI Proxy API service..."
systemctl --user enable cliproxyapi.service --now
systemctl --user restart cliproxyapi.service

# 6. Kiểm tra service
sleep 4
echo "📊 Trạng thái service:"
systemctl --user status cliproxyapi.service --no-pager | head -n 15

# 7. Lấy IP public
IP=$(curl -s ifconfig.me)

echo ""
echo "🎉 SETUP HOÀN TẤT 100% !"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📍 Link WebUI Management Center:"
echo "   http://$IP:8317/management.html"
echo ""
echo "🔑 Management Key (copy nguyên dòng):"
echo "$SECRET_KEY"
echo ""
echo "📌 Hướng dẫn sử dụng:"
echo "   1. Mở link trên bằng Chrome/Firefox"
echo "   2. Dán Management Key vào ô và nhấn Connect"
echo "   3. Vào OAuth để login Gemini / Claude / Grok / Codex..."
echo ""
echo "🔄 Các lệnh quản lý sau này:"
echo "   systemctl --user status cliproxyapi.service     # xem trạng thái"
echo "   systemctl --user restart cliproxyapi.service    # restart"
echo "   journalctl --user -u cliproxyapi.service -f    # xem log"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Chúc bạn dùng vui vẻ! Nếu cần hỗ trợ thêm thì ping mình nhé 🚀"
