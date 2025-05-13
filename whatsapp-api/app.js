const express = require('express');
const { Client, LocalAuth } = require('whatsapp-web.js');
const qrcode = require('qrcode-terminal');
const session = require('./persist-session');

const app = express();
app.use(express.json());

// Variável para armazenar o último QR code
let lastQR = null;

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
    }
});

let isReady = false;

client.on('qr', (qr) => {
    console.log('QR Code recebido, escaneie para autenticar!');
    lastQR = qr; // Armazena o último QR code
    qrcode.generate(qr, { small: true }); // Mantém a visualização no console também
});

client.on('ready', () => {
    console.log('Cliente WhatsApp está pronto!');
    isReady = true;
    lastQR = null; // Limpa o QR code quando autenticado
});

client.on('authenticated', () => {
    console.log('WhatsApp autenticado!');
    lastQR = null; // Limpa o QR code quando autenticado
});

client.on('auth_failure', () => {
    console.log('Falha na autenticação do WhatsApp');
    isReady = false;
});

// Adiciona handler de erro para o cliente
client.on('disconnected', (reason) => {
    console.log('Cliente desconectado:', reason);
    isReady = false;
    // Tenta reconectar
    client.initialize();
});

client.initialize().catch(err => {
    console.error('Erro ao inicializar cliente:', err);
});

// Endpoint para obter o QR code
app.get('/qr-code', (req, res) => {
    if (isReady) {
        res.json({ status: 'ready', qr: null });
    } else if (lastQR) {
        res.json({ status: 'pending', qr: lastQR });
    } else {
        res.json({ status: 'initializing', qr: null });
    }
});

// Endpoint para enviar mensagem
app.post('/send-message', async (req, res) => {
    if (!isReady) {
        return res.status(503).json({ error: 'WhatsApp ainda não está pronto' });
    }

    const { phone, message } = req.body;

    try {
        // Remove qualquer formatação do número e garante que começa com @c.us
        const formattedNumber = phone.replace(/[^\d]/g, '') + '@c.us';
        
        await client.sendMessage(formattedNumber, message);
        res.json({ success: true });
    } catch (error) {
        console.error('Erro ao enviar mensagem:', error);
        res.status(500).json({ error: 'Erro ao enviar mensagem' });
    }
});

// Endpoint de status
app.get('/status', (req, res) => {
    res.json({ 
        status: isReady ? 'ready' : 'initializing',
        authenticated: isReady
    });
});

const PORT = process.env.PORT || 3001;
app.listen(PORT, () => {
    console.log(`Servidor rodando na porta ${PORT}`);
}); 