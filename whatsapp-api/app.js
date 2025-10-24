console.log('🚀 Starting WhatsApp API service...');

const express = require('express');
const cors = require('cors');
const { Client, LocalAuth } = require('whatsapp-web.js');
const qrcode = require('qrcode-terminal');
const session = require('./persist-session');

console.log('📦 Dependencies loaded successfully');

function logWithTimestamp(message, data = null) {
    const timestamp = new Date().toISOString();
    console.log(`[${timestamp}] ${message}`);
    if (data) {
        console.log(JSON.stringify(data, null, 2));
    }
}

const app = express();
app.use(cors({
    origin: ['http://localhost:3000', 'http://127.0.0.1:3000', 'http://localhost.billbuddy.com.br:3000'],
    methods: ['GET', 'POST'],
    credentials: true
}));

app.use(express.json());

let isReady = false;
let isAuthenticated = false;
let lastQR = null;
let connectionRetries = 0;
let client = null;
let isInitializing = false;

async function cleanupClient() {
    if (client) {
        try {
            logWithTimestamp('Limpando cliente existente...');
            await client.destroy();
            client = null;
            logWithTimestamp('Cliente limpo com sucesso');
        } catch (error) {
            logWithTimestamp('Erro ao limpar cliente:', error.message);
        }
    }
    isReady = false;
    isAuthenticated = false;
    lastQR = null;
}

async function initializeClient() {
    if (isInitializing) {
        logWithTimestamp('Cliente já está sendo inicializado, aguardando...');
        return;
    }

    isInitializing = true;
    await cleanupClient();

    try {
        logWithTimestamp('Inicializando novo cliente WhatsApp...');
        
        client = new Client({
            authStrategy: new LocalAuth({
                clientId: session.sessionName,
                dataPath: session.sessionDir
            }),
            puppeteer: {
                headless: true,
                args: [
                    '--no-sandbox',
                    '--disable-setuid-sandbox',
                    '--disable-dev-shm-usage'
                ]
            }
        });

        setupClientEvents();
        await client.initialize();
        
    } catch (error) {
        logWithTimestamp('Erro ao inicializar cliente:', error.message);
        await cleanupClient();
    } finally {
        isInitializing = false;
    }
}

function setupClientEvents() {
    if (!client) return;

    client.on('qr', (qr) => {
        logWithTimestamp('📱 QR Code recebido - escaneie com seu WhatsApp');
        lastQR = qr;
        qrcode.generate(qr, { small: true });
    });

    client.on('loading_screen', (percent, message) => {
        logWithTimestamp(`Carregando: ${percent}% - ${message}`);
    });

    client.on('ready', async () => {
        logWithTimestamp('✅ Cliente WhatsApp pronto!');
        isReady = true;
        isAuthenticated = true;
        lastQR = null;
        connectionRetries = 0;
    });

    client.on('authenticated', async () => {
        logWithTimestamp('✅ WhatsApp autenticado e pronto!');
        isAuthenticated = true;
        isReady = true;
        lastQR = null;
        connectionRetries = 0;
    });

    client.on('auth_failure', (error) => {
        logWithTimestamp('Falha na autenticação do WhatsApp:', error.message);
        isReady = false;
        isAuthenticated = false;
        setTimeout(() => restartClient(), 5000);
    });

    client.on('disconnected', async (reason) => {
        logWithTimestamp('Cliente desconectado:', { reason });
        isReady = false;
        isAuthenticated = false;
        setTimeout(() => restartClient(), 5000);
    });

    client.on('change_state', (state) => {
        logWithTimestamp('Mudança de estado:', { state });
    });
}

async function restartClient() {
    logWithTimestamp('Reiniciando cliente WhatsApp...');
    await cleanupClient();
    setTimeout(() => initializeClient(), 2000);
    return true;
}

app.get('/qr-code', (req, res) => {
    try {
        if (isAuthenticated && isReady) {
            res.json({ status: 'ready', qr: null, authenticated: true });
        } else if (lastQR) {
            res.json({ status: 'pending', qr: lastQR, authenticated: false });
        } else if (isInitializing) {
            res.json({ status: 'initializing', qr: null, authenticated: false });
        } else {
            res.json({ status: 'waiting', qr: null, authenticated: false });
        }
    } catch (error) {
        logWithTimestamp('Erro no endpoint qr-code:', error.message);
        res.json({ status: 'error', error: error.message, authenticated: false });
    }
});

app.post('/send-message', async (req, res) => {
    logWithTimestamp('📱 Recebida requisição de envio de mensagem');
    
    const { phone, message } = req.body;

    if (!phone || !message) {
        logWithTimestamp('❌ Telefone ou mensagem faltando');
        return res.status(400).json({ error: 'Phone and message are required' });
    }

    if (!client || !isReady || !isAuthenticated) {
        logWithTimestamp('❌ WhatsApp não está pronto', { client: !!client, isReady, isAuthenticated });
        return res.status(503).json({ 
            error: 'WhatsApp service is not ready yet. Please try again in a moment.',
            details: 'SERVICE_NOT_READY'
        });
    }

    try {
        const cleanPhone = phone.replace(/[^\d]/g, '');
        const formattedNumber = cleanPhone + '@c.us';
        
        logWithTimestamp('📤 Enviando mensagem', { 
            phone: cleanPhone,
            messageLength: message.length
        });
        
        const result = await client.sendMessage(formattedNumber, message);
        
        logWithTimestamp('✅ Mensagem enviada com sucesso!');
        return res.json({ success: true, message: 'Message sent successfully' });
        
    } catch (error) {
        logWithTimestamp('❌ Erro ao enviar mensagem:', error.message);
        
        if (error.message.includes('not registered')) {
            return res.status(400).json({ 
                error: 'Phone number not registered on WhatsApp',
                details: 'PHONE_NOT_REGISTERED'
            });
        } else {
            return res.status(500).json({ 
                error: 'Failed to send message',
                details: error.message 
            });
        }
    }
});

app.get('/status', async (req, res) => {
    try {
        if (!client) {
            res.json({ 
                status: 'stopped',
                authenticated: false,
                error: 'Cliente não inicializado'
            });
            return;
        }

        if (isInitializing) {
            res.json({ 
                status: 'initializing',
                authenticated: false
            });
            return;
        }

        const state = await client.getState();
        const finalStatus = isAuthenticated ? 'ready' : (lastQR ? 'pending' : 'initializing');
        
        res.json({ 
            status: finalStatus,
            authenticated: isAuthenticated,
            ready: isReady,
            state: state,
            retries: connectionRetries
        });
    } catch (error) {
        logWithTimestamp('Erro no endpoint status:', error.message);
        res.json({ 
            status: 'error',
            authenticated: false,
            error: error.message,
            retries: connectionRetries
        });
    }
});

app.post('/restart', async (req, res) => {
    try {
        logWithTimestamp('Reinicialização forçada solicitada');
        connectionRetries = 0;
        await restartClient();
        res.json({ success: true, message: 'Reinicialização iniciada' });
    } catch (error) {
        logWithTimestamp('Erro ao reiniciar:', error.message);
        res.status(500).json({ error: 'Erro ao reiniciar serviço' });
    }
});

const PORT = process.env.PORT || 3001;
console.log(`🌐 Attempting to start server on port ${PORT}...`);

const server = app.listen(PORT, '0.0.0.0', () => {
    logWithTimestamp(`Servidor rodando na porta ${PORT}`);
    console.log(`✅ Server successfully started on http://0.0.0.0:${PORT}`);
    setTimeout(() => initializeClient(), 1000);
});

server.on('error', (error) => {
    console.error('❌ Server error:', error);
    if (error.code === 'EADDRINUSE') {
        console.error(`❌ Port ${PORT} is already in use`);
    }
    process.exit(1);
});

process.on('SIGINT', async () => {
    logWithTimestamp('Recebido SIGINT, encerrando graciosamente...');
    await cleanupClient();
    server.close(() => {
        logWithTimestamp('Servidor encerrado');
        process.exit(0);
    });
});

process.on('SIGTERM', async () => {
    logWithTimestamp('Recebido SIGTERM, encerrando graciosamente...');
    await cleanupClient();
    server.close(() => {
        logWithTimestamp('Servidor encerrado');
        process.exit(0);
    });
});