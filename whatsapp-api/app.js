const express = require('express');
const { Client, LocalAuth } = require('whatsapp-web.js');
const qrcode = require('qrcode-terminal');
const session = require('./persist-session');

// Função para logging mais detalhado
function logWithTimestamp(message, data = null) {
    const timestamp = new Date().toISOString();
    console.log(`[${timestamp}] ${message}`);
    if (data) {
        console.log(JSON.stringify(data, null, 2));
    }
}

const app = express();
app.use(express.json());

// Variáveis de controle
let isReady = false;
let lastQR = null;
let connectionRetries = 0;
const MAX_RETRIES = 3;

// Inicializa o cliente do WhatsApp com autenticação local persistente
const client = new Client({
    authStrategy: new LocalAuth({
        clientId: session.sessionName,
        dataPath: session.sessionDir
    }),
    puppeteer: {
        headless: true,
        args: [
            '--no-sandbox',
            '--disable-setuid-sandbox',
            '--disable-dev-shm-usage',
            '--disable-accelerated-2d-canvas',
            '--no-first-run',
            '--no-zygote',
            '--disable-gpu'
        ]
    },
    qrMaxRetries: 5,
    authTimeoutMs: 60000,
    restartOnAuthFail: true,
    takeoverOnConflict: true,
    takeoverTimeoutMs: 10000
});

// Função para reiniciar o cliente
async function restartClient() {
    if (connectionRetries >= MAX_RETRIES) {
        logWithTimestamp('Número máximo de tentativas de reconexão atingido');
        return;
    }
    
    connectionRetries++;
    logWithTimestamp(`Tentativa de reinicialização ${connectionRetries}/${MAX_RETRIES}`);
    
    try {
        await client.destroy();
        logWithTimestamp('Cliente destruído, reiniciando...');
        setTimeout(async () => {
            try {
                await client.initialize();
            } catch (error) {
                logWithTimestamp('Erro ao reinicializar cliente:', error);
            }
        }, 5000);
    } catch (error) {
        logWithTimestamp('Erro ao destruir cliente:', error);
    }
}

// Eventos do cliente WhatsApp
client.on('qr', (qr) => {
    logWithTimestamp('QR Code recebido, escaneie para autenticar!');
    lastQR = qr;
    qrcode.generate(qr, { small: true });
});

client.on('loading_screen', (percent, message) => {
    logWithTimestamp(`Carregando: ${percent}% - ${message}`);
});

client.on('ready', async () => {
    logWithTimestamp('Cliente WhatsApp está pronto!');
    try {
        const state = await client.getState();
        logWithTimestamp('Estado atual do cliente:', { state });
        isReady = true;
        lastQR = null;
        connectionRetries = 0;
    } catch (error) {
        logWithTimestamp('Erro ao obter estado do cliente:', error);
    }
});

client.on('authenticated', async (session) => {
    logWithTimestamp('WhatsApp autenticado com sucesso!');
    try {
        const state = await client.getState();
        logWithTimestamp('Estado após autenticação:', { state });
    } catch (error) {
        logWithTimestamp('Erro ao verificar estado após autenticação:', error);
    }
});

client.on('auth_failure', (error) => {
    logWithTimestamp('Falha na autenticação do WhatsApp:', error);
    isReady = false;
    restartClient();
});

client.on('disconnected', async (reason) => {
    logWithTimestamp('Cliente desconectado:', { reason });
    isReady = false;
    await restartClient();
});

// Inicialização do cliente com tratamento de erro
client.initialize().catch(err => {
    logWithTimestamp('Erro ao inicializar cliente:', err);
});

// Endpoints da API
app.get('/qr-code', (req, res) => {
    if (isReady) {
        res.json({ status: 'ready', qr: null });
    } else if (lastQR) {
        res.json({ status: 'pending', qr: lastQR });
    } else {
        res.json({ status: 'initializing', qr: null });
    }
});

app.post('/send-message', async (req, res) => {
    if (!isReady) {
        logWithTimestamp('Tentativa de envio com cliente não pronto');
        return res.status(503).json({ error: 'WhatsApp ainda não está pronto' });
    }

    const { phone, message } = req.body;

    try {
        const formattedNumber = phone.replace(/[^\d]/g, '') + '@c.us';
        logWithTimestamp('Tentando enviar mensagem para:', { number: formattedNumber });
        
        // Verifica se o número existe no WhatsApp
        const isRegistered = await client.isRegisteredUser(formattedNumber);
        if (!isRegistered) {
            logWithTimestamp('Número não registrado no WhatsApp:', { number: formattedNumber });
            return res.status(400).json({ error: 'Número não registrado no WhatsApp' });
        }

        await client.sendMessage(formattedNumber, message);
        logWithTimestamp('Mensagem enviada com sucesso para:', { number: formattedNumber });
        res.json({ success: true });
    } catch (error) {
        logWithTimestamp('Erro ao enviar mensagem:', error);
        res.status(500).json({ error: 'Erro ao enviar mensagem' });
    }
});

app.get('/status', async (req, res) => {
    try {
        const state = await client.getState();
        res.json({ 
            status: isReady ? 'ready' : 'initializing',
            authenticated: isReady,
            state: state
        });
    } catch (error) {
        res.json({ 
            status: 'error',
            authenticated: isReady,
            error: error.message
        });
    }
});

const PORT = process.env.PORT || 3001;
app.listen(PORT, () => {
    logWithTimestamp(`Servidor rodando na porta ${PORT}`);
});