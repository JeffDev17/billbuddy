#!/bin/bash

# Função para iniciar o Rails
start_rails() {
    echo "Iniciando Rails server na porta 3001..."
    cd /Users/jeffdev/Documents/projects/billbuddy
    bundle exec rails server -p 3001
}

# Função para iniciar a API do WhatsApp
start_whatsapp() {
    echo "Iniciando WhatsApp API na porta 3000..."
    cd /Users/jeffdev/Documents/projects/billbuddy/whatsapp-api
    npm start
}

# Verifica se tmux está instalado
if ! command -v tmux &> /dev/null; then
    echo "tmux não está instalado. Instalando via Homebrew..."
    brew install tmux
fi

# Nome da sessão tmux
SESSION_NAME="billbuddy"

# Mata a sessão existente se houver
tmux kill-session -t $SESSION_NAME 2>/dev/null

# Cria uma nova sessão tmux
tmux new-session -d -s $SESSION_NAME

# Divide a janela horizontalmente
tmux split-window -h -t $SESSION_NAME

# Inicia Rails no primeiro painel
tmux send-keys -t $SESSION_NAME:0.0 "$(declare -f start_rails); start_rails" C-m

# Inicia WhatsApp API no segundo painel
tmux send-keys -t $SESSION_NAME:0.1 "$(declare -f start_whatsapp); start_whatsapp" C-m

# Anexa à sessão
tmux attach-session -t $SESSION_NAME

echo "Serviços iniciados em segundo plano. Use 'tmux attach -t billbuddy' para ver os logs." 