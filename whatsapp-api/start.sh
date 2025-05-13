#!/bin/bash

# Verifica se o Node.js está instalado
if ! command -v node &> /dev/null; then
    echo "Node.js não está instalado. Por favor, instale o Node.js primeiro."
    exit 1
fi

# Verifica se as dependências estão instaladas
if [ ! -d "node_modules" ]; then
    echo "Instalando dependências..."
    npm install
fi

# Inicia a API
echo "Iniciando a API do WhatsApp..."
node app.js 