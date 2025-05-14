# Use uma imagem Node.js LTS com Debian
FROM node:18-bullseye-slim

# Evita problemas de interatividade durante a instalação
ENV DEBIAN_FRONTEND=noninteractive

# Instala as dependências necessárias
RUN apt-get update && apt-get install -y \
    chromium \
    chromium-sandbox \
    fonts-liberation \
    libasound2 \
    libatk-bridge2.0-0 \
    libatk1.0-0 \
    libatspi2.0-0 \
    libcairo2 \
    libcups2 \
    libdbus-1-3 \
    libdrm2 \
    libgbm1 \
    libglib2.0-0 \
    libnspr4 \
    libnss3 \
    libpango-1.0-0 \
    libx11-6 \
    libx11-xcb1 \
    libxcb1 \
    libxcomposite1 \
    libxdamage1 \
    libxext6 \
    libxfixes3 \
    libxrandr2 \
    libxshmfence1 \
    xdg-utils \
    wget \
    ca-certificates \
    procps \
    --no-install-recommends \
    && rm -rf /var/lib/apt/lists/*

# Define variáveis de ambiente para o Puppeteer
ENV PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true
ENV PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium
ENV NODE_ENV=production

# Cria um usuário não-root para segurança
RUN groupadd -r pptruser && useradd -r -g pptruser -G audio,video pptruser \
    && mkdir -p /home/pptruser/Downloads \
    && chown -R pptruser:pptruser /home/pptruser

# Define o diretório de trabalho
WORKDIR /home/pptruser/app

# Copia os arquivos de dependências
COPY package*.json ./

# Instala as dependências
RUN npm ci --only=production

# Copia o código da aplicação
COPY . .

# Cria e configura diretórios necessários
RUN mkdir -p .wwebjs_auth/session-billbuddy-md \
    && chown -R pptruser:pptruser . \
    && chmod -R 777 .wwebjs_auth

# Configura diretório para cache do Puppeteer
RUN mkdir -p /home/pptruser/.cache/puppeteer \
    && chown -R pptruser:pptruser /home/pptruser/.cache \
    && chmod -R 777 /home/pptruser/.cache

# Muda para o usuário não-root
USER pptruser

# Expõe a porta da API
EXPOSE 3001

# Comando para iniciar a aplicação
CMD ["node", "app.js"]