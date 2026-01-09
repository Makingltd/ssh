#!/bin/bash
set -e

# ========= 参数 =========
KEY_NAME="${1:-$KEY_NAME}"

if [[ -z "$KEY_NAME" ]]; then
  echo "❌ 必须指定密钥名"
  echo "示例："
  echo "curl -fsSL https://xxx.xx/x/xx.sh | bash -s xx"
  exit 1
fi

if [ "$EUID" -ne 0 ]; then
  echo "❌ 请使用 root 执行"
  exit 1
fi

SSH_DIR="/root/.ssh"
KEY_PATH="${SSH_DIR}/${KEY_NAME}"

echo "== VPS SSH 初始化（Key Only） =="
echo "KEY_NAME: ${KEY_NAME}"
echo

# ========= SSH 目录 =========
mkdir -p "$SSH_DIR"
chmod 700 "$SSH_DIR"

# ========= 生成密钥 =========
if [ ! -f "$KEY_PATH" ]; then
  echo "[1/7] 生成 ed25519 密钥"
  ssh-keygen -t ed25519 -f "$KEY_PATH" -N "" -C "vps-${KEY_NAME}"
else
  echo "[1/7] 密钥已存在，跳过"
fi

# ========= authorized_keys =========
echo "[2/7] 配置 authorized_keys"
touch "${SSH_DIR}/authorized_keys"
chmod 600 "${SSH_DIR}/authorized_keys"

PUB_KEY="$(cat "${KEY_PATH}.pub")"
grep -qxF "$PUB_KEY" "${SSH_DIR}/authorized_keys" || \
  echo "$PUB_KEY" >> "${SSH_DIR}/authorized_keys"

# ========= 备份 sshd =========
echo "[3/7] 备份 sshd_config"
cp /etc/ssh/sshd_config "/etc/ssh/sshd_config.bak.$(date +%F_%H%M%S)"

# ========= SSH 加固（不改 22） =========
echo "[4/7] 加固 SSH（保留 22 端口）"
sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
sed -i 's/^#\?KbdInteractiveAuthentication.*/KbdInteractiveAuthentication no/' /etc/ssh/sshd_config
sed -i 's/^#\?PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin prohibit-password/' /etc/ssh/sshd_config

# ========= 校验 =========
echo "[5/7] 校验 SSH 配置"
sshd -t

# ========= 重载 =========
echo "[6/7] 重载 SSH"
systemctl reload ssh

# ========= 输出私钥（关键优化） =========
echo "[7/7] 输出私钥（请立即保存）"
echo
echo "================= SSH PRIVATE KEY ================="
cat "$KEY_PATH"
echo "================= END SSH PRIVATE KEY ============="
echo

echo "✅ 初始化完成（22 端口未修改）"
echo
echo "👉 下一步你可以："
echo "  • 直接复制上面的私钥到 Termius"
echo "  • 或保存为 ~/.ssh/${KEY_NAME} 后登录"
echo
echo "🧪 测试："
echo "ssh -i ~/.ssh/${KEY_NAME} root@服务器IP"
echo
echo "⚠️ 强烈建议：保存好私钥后，再关闭当前 SSH 会话"
