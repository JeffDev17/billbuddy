#!/bin/bash

# Cores para output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Função para exibir mensagens
echo_status() {
    echo -e "${GREEN}==>${NC} $1"
}

echo_warning() {
    echo -e "${YELLOW}==>${NC} $1"
}

# Verifica se o arquivo .env existe
if [ ! -f .env ]; then
    echo_warning "Arquivo .env não encontrado. Criando a partir do .env.example..."
    cp .env.example .env
    echo_status "Por favor, edite o arquivo .env com suas configurações antes de continuar."
    exit 1
fi

# Função para iniciar os containers
start_services() {
    echo_status "Iniciando os serviços Docker..."
    docker-compose up -d
    
    echo_status "Aguardando o banco de dados..."
    sleep 5
    
    echo_status "Executando migrações do banco de dados..."
    docker-compose exec rails rails db:migrate
    
    echo_status "Serviços iniciados com sucesso!"
    echo_status "Rails: http://localhost:3001"
    echo_status "WhatsApp API: http://localhost:3000"
    
    echo_warning "Para ver os logs: docker-compose logs -f"
    echo_warning "Para parar os serviços: ./docker-start.sh stop"
}

# Função para parar os containers
stop_services() {
    echo_status "Parando os serviços..."
    docker-compose down
    echo_status "Serviços parados com sucesso!"
}

# Função para reiniciar os containers
restart_services() {
    stop_services
    start_services
}

# Função para mostrar os logs
show_logs() {
    docker-compose logs -f
}

# Menu de comandos
case "$1" in
    "start")
        start_services
        ;;
    "stop")
        stop_services
        ;;
    "restart")
        restart_services
        ;;
    "logs")
        show_logs
        ;;
    *)
        echo "Uso: $0 {start|stop|restart|logs}"
        exit 1
        ;;
esac 