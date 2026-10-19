#!/bin/zsh
# Remove o Disco Livre por completo, mesmo se você só arrastou o app pra Lixeira.
# Funciona de qualquer lugar:
#   zsh -c "$(curl -fsSL https://raw.githubusercontent.com/Willclaf/disco-livre/main/uninstall.sh)"
launchctl bootout "gui/$(id -u)/com.disco-livre.vigia" 2>/dev/null
rm -f "$HOME/Library/LaunchAgents/com.disco-livre.vigia.plist"
pkill -x DiscoLivre 2>/dev/null
rm -rf "/Applications/Disco Livre.app" "$HOME/Applications/Disco Livre.app"
rm -f "$HOME/.local/bin/disco-livre"
rm -rf "$HOME/.claude/skills/disco-livre" "$HOME/.codex/skills/disco-livre" "$HOME/.config/disco-livre"
tccutil reset All com.disco-livre.app >/dev/null 2>&1
print -r -- "✓ Disco Livre removido por completo. (O histórico fica em ~/Library/Logs/disco-livre.log)"
