const express = require('express');
const cors = require('cors');
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

// Configure CORS
const app = express();
app.use(cors({
    origin: ['http://localhost:3000', 'http://127.0.0.1:3000', 'http://localhost.billbuddy.com.br:3000'],
    methods: ['GET', 'POST'],
    credentials: true
}));

app.use(express.json());

// Variáveis de controle
let isReady = false;
let isAuthenticated = false;
let lastQR = null;
let connectionRetries = 0;
let client = null;
let isInitializing = false;
const MAX_RETRIES = 3;
const INIT_TIMEOUT = 300000; // 5 minutes
const QR_TIMEOUT = 180000; // 3 minutes

// Função para limpar cliente existente
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

// Função para inicializar o cliente
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
                    '--disable-dev-shm-usage',
                    '--disable-accelerated-2d-canvas',
                    '--no-first-run',
                    '--no-zygote',
                    '--disable-gpu',
                    '--disable-web-security',
                    '--disable-features=VizDisplayCompositor'
                ]
            },
            qrMaxRetries: 10, // Increase retries
            authTimeoutMs: INIT_TIMEOUT,
            restartOnAuthFail: false, // Evitar loops infinitos
            takeoverOnConflict: false,
            takeoverTimeoutMs: 10000
        });

        setupClientEvents();
        
        // Timeout para inicialização
        const initTimeout = setTimeout(() => {
            logWithTimestamp('Timeout na inicialização do cliente');
            cleanupClient().then(() => {
                isInitializing = false;
            });
        }, INIT_TIMEOUT);

        await client.initialize();
        clearTimeout(initTimeout);
        
    } catch (error) {
        logWithTimestamp('Erro ao inicializar cliente:', error.message);
        await cleanupClient();
    } finally {
        isInitializing = false;
    }
}

// Configurar eventos do cliente
function setupClientEvents() {
    if (!client) return;

    // QR Code event
    client.on('qr', (qr) => {
        logWithTimestamp('QR Code recebido');
        lastQR = qr;
        qrcode.generate(qr, { small: true });
        
        // Timeout para QR code
        setTimeout(() => {
            if (lastQR === qr && !isAuthenticated) {
                logWithTimestamp('QR Code expirou, reiniciando...');
                restartClient();
            }
        }, QR_TIMEOUT);
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
            isAuthenticated = true;
            lastQR = null;
            connectionRetries = 0;
        } catch (error) {
            logWithTimestamp('Erro ao obter estado do cliente:', error.message);
        }
    });

    client.on('authenticated', async () => {
        logWithTimestamp('WhatsApp autenticado com sucesso!');
        isAuthenticated = true;
        lastQR = null;
        try {
            const state = await client.getState();
            logWithTimestamp('Estado após autenticação:', { state });
        } catch (error) {
            logWithTimestamp('Erro ao verificar estado após autenticação:', error.message);
        }
    });

    client.on('auth_failure', (error) => {
        logWithTimestamp('Falha na autenticação do WhatsApp:', error.message);
        isReady = false;
        isAuthenticated = false;
        setTimeout(() => restartClient(), 5000); // Aguardar 5s antes de reiniciar
    });

    client.on('disconnected', async (reason) => {
        logWithTimestamp('Cliente desconectado:', { reason });
        isReady = false;
        isAuthenticated = false;
        
        // Don't restart immediately if QR retries were reached - let user manually restart
        if (reason === 'Max qrcode retries reached') {
            logWithTimestamp('QR Code retries esgotados. Aguardando reinício manual...');
            lastQR = null;
        } else {
            setTimeout(() => restartClient(), 5000); // Aguardar 5s antes de reiniciar
        }
    });

    client.on('change_state', (state) => {
        logWithTimestamp('Mudança de estado:', { state });
    });
}

// Função para reiniciar o cliente
async function restartClient() {
    if (connectionRetries >= MAX_RETRIES) {
        logWithTimestamp('Número máximo de tentativas de reconexão atingido');
        return false;
    }
    
    connectionRetries++;
    logWithTimestamp(`Tentativa de reinicialização ${connectionRetries}/${MAX_RETRIES}`);
    
    await cleanupClient();
    
    setTimeout(async () => {
        try {
            await initializeClient();
        } catch (error) {
            logWithTimestamp('Erro ao reinicializar cliente:', error.message);
        }
    }, 5000); // Aguardar 5s antes de reiniciar
    
    return true;
}

// Endpoints da API
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
    if (!isReady || !isAuthenticated || !client) {
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
        logWithTimestamp('Erro ao enviar mensagem:', error.message);
        res.status(500).json({ error: 'Erro ao enviar mensagem' });
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
        res.json({ 
            status: isReady ? 'ready' : (lastQR ? 'pending' : 'initializing'),
            authenticated: isAuthenticated && isReady,
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

// Endpoint para forçar reinicialização
app.post('/restart', async (req, res) => {
    try {
        logWithTimestamp('Reinicialização forçada solicitada');
        connectionRetries = 0; // Reset do contador
        await restartClient();
        res.json({ success: true, message: 'Reinicialização iniciada' });
    } catch (error) {
        logWithTimestamp('Erro ao reiniciar:', error.message);
        res.status(500).json({ error: 'Erro ao reiniciar serviço' });
    }
});

const PORT = process.env.PORT || 3001;
const server = app.listen(PORT, '0.0.0.0', () => {
    logWithTimestamp(`Servidor rodando na porta ${PORT}`);
    // Inicializar cliente automaticamente
    setTimeout(() => initializeClient(), 1000);
});

// Graceful shutdown
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