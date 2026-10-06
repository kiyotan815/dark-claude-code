#!/usr/bin/env bash
#
# devcontainer 作成後セットアップ。
# 目的: コンテナを開いたら Claude Code がすぐ使える状態にする。
#   1. 永続化した ~/.claude / ~/.codex volume の所有者を修正
#   2. Claude Code CLI / Codex CLI を global install（常に @latest へ更新）
#   3. リポジトリの dev 依存 (eslint / markdownlint) を install
#   4. rules/ を ~/.claude/rules/ へ配置
#   5. claude-global/ (グローバル CLAUDE.md / settings.json / statusline.sh) を ~/.claude/ へ配置
#   6. codex-global/ (config.toml / AGENTS.md) を ~/.codex/ へ配置
#   7. キット plugin (dcc@dark-claude-code) を marketplace 登録 + install
#      （このキット自体を開いている場合はローカルパス、それ以外は GitHub から）
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
HOME_CLAUDE="${HOME}/.claude"
HOME_CODEX="${HOME}/.codex"
KIT_REPO="kiyotan815/dark-claude-code"
MARKETPLACE="dark-claude-code"
PLUGIN="dcc@$MARKETPLACE"

log() { printf '\033[36m[devcontainer]\033[0m %s\n' "$*"; }

# rsync があれば使い、無ければ cp にフォールバック
# -L: キット内の symlink（codex-global/AGENTS.md 等）は実体化して配る
copy_dir() {
  local src="$1" dst="$2"
  mkdir -p "$dst"
  if command -v rsync >/dev/null 2>&1; then
    rsync -aL --update "$src/" "$dst/"
  else
    cp -aL "$src/." "$dst/"
  fi
}

# 1. ~/.claude / ~/.codex は named volume マウントなので初期所有者が root のことがある
for vol in "$HOME_CLAUDE" "$HOME_CODEX"; do
  if [ -d "$vol" ]; then
    sudo chown -R "$(id -u):$(id -g)" "$vol" 2>/dev/null || true
  fi
done
mkdir -p "$HOME_CLAUDE/rules" "$HOME_CODEX"

# 2. Claude Code CLI / Codex CLI（常に @latest へ。既存コンテナでも postCreate 再実行で更新される）
log "Installing/updating Claude Code CLI + Codex CLI (@latest)..."
npm install -g @anthropic-ai/claude-code@latest @openai/codex@latest
log "Claude Code CLI: $(claude --version 2>/dev/null || echo '?') / Codex CLI: $(codex --version 2>/dev/null || echo '?')"

# 3. リポジトリ dev 依存（キットの lint / validate 用）
if [ -f "$REPO_ROOT/package-lock.json" ]; then
  log "Installing npm dependencies (npm ci)..."
  (cd "$REPO_ROOT" && npm ci)
fi

# 4. rules/ -> ~/.claude/rules/（グローバル配置。plugin には含まれない）
if [ -d "$REPO_ROOT/rules" ]; then
  log "Deploying rules/ -> ~/.claude/rules/"
  copy_dir "$REPO_ROOT/rules" "$HOME_CLAUDE/rules"
fi

# 5. claude-global/ -> ~/.claude/（グローバル CLAUDE.md / settings.json / statusline.sh）
if [ -d "$REPO_ROOT/claude-global" ]; then
  log "Deploying claude-global/ -> ~/.claude/"
  copy_dir "$REPO_ROOT/claude-global" "$HOME_CLAUDE"
  chmod +x "$HOME_CLAUDE/statusline.sh" 2>/dev/null || true
  # statusline.sh が使う jq / bc が image に無ければ install
  if ! command -v jq >/dev/null 2>&1 || ! command -v bc >/dev/null 2>&1; then
    log "Installing statusline deps (jq, bc)..."
    sudo apt-get update -qq && sudo apt-get install -y -qq jq bc
  fi
fi

# 6. codex-global/ -> ~/.codex/（config.toml / AGENTS.md。auth.json は含めない）
if [ -d "$REPO_ROOT/codex-global" ]; then
  log "Deploying codex-global/ -> ~/.codex/"
  copy_dir "$REPO_ROOT/codex-global" "$HOME_CODEX"
fi

# 7. キット plugin を登録 + install（~/.claude volume に永続化されるので一度で済む）
#    このキット自体を開いているときはローカルパスを使い、編集がそのまま反映される
if command -v claude >/dev/null 2>&1; then
  if [ -f "$REPO_ROOT/.claude-plugin/plugin.json" ] && grep -q '"name": *"dcc"' "$REPO_ROOT/.claude-plugin/plugin.json"; then
    source_spec="$REPO_ROOT"
  else
    source_spec="$KIT_REPO"
  fi
  if claude plugin marketplace list 2>/dev/null | grep -q "$MARKETPLACE"; then
    log "marketplace $MARKETPLACE: already registered"
  else
    log "Registering marketplace $MARKETPLACE ($source_spec)..."
    claude plugin marketplace add "$source_spec" || log "warn: marketplace add failed (ネットワーク/認証を確認して再実行: claude plugin marketplace add $source_spec)"
  fi
  if claude plugin list 2>/dev/null | grep -q "$PLUGIN"; then
    log "plugin $PLUGIN: already installed"
  else
    claude plugin install "$PLUGIN" || log "warn: plugin install failed (再実行: claude plugin install $PLUGIN)"
  fi
fi

log "Setup complete."
if [ -z "${ANTHROPIC_API_KEY:-}" ]; then
  log "Tip: ANTHROPIC_API_KEY 未設定。'claude' 実行後にログイン (login 状態は volume に永続化)。"
fi
if [ -z "${OPENAI_API_KEY:-}" ] && [ ! -f "$HOME_CODEX/auth.json" ]; then
  log "Tip: Codex 未認証。OPENAI_API_KEY を設定するか、host の ~/.codex/auth.json を volume へコピー (README 参照)。"
fi
