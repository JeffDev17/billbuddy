const fs = require('fs');
const path = require('path');

// Diretório para armazenar a sessão
const SESSION_DIR = path.join(__dirname, '.wwebjs_auth');
const MULTI_DEVICE_DIR = path.join(SESSION_DIR, 'session-billbuddy-md');

// Garante que o diretório existe
if (!fs.existsSync(SESSION_DIR)) {
    fs.mkdirSync(SESSION_DIR, { recursive: true });
}

if (!fs.existsSync(MULTI_DEVICE_DIR)) {
    fs.mkdirSync(MULTI_DEVICE_DIR, { recursive: true });
}

module.exports = {
    sessionDir: MULTI_DEVICE_DIR,
    sessionName: 'session-billbuddy'
}; 