# WhatsApp API Service

Este serviço é responsável pela integração com o WhatsApp, permitindo o envio de mensagens através da API.

## Configuração da Autenticação do WhatsApp

Para configurar a autenticação do WhatsApp, siga estes passos:

1. **Autenticação Local (Desenvolvimento)**
   ```bash
   # Instale as dependências
   npm install

   # Execute a aplicação localmente
   PORT=3002 node app.js
   ```
   - Um QR Code será exibido no terminal
   - Escaneie o QR Code com seu WhatsApp
   - Após a autenticação, uma pasta `.wwebjs_auth` será criada localmente

2. **Configuração no Docker**
   - A pasta `.wwebjs_auth` é mapeada para um volume Docker chamado `whatsapp_auth`
   - O volume persiste a autenticação entre reinicializações do container
   - O mapeamento é configurado no `docker-compose.yml`:
     ```yaml
     volumes:
       - ./whatsapp-api:/app
       - whatsapp_auth:/app/.wwebjs_auth
     ```

## Endpoints

- `GET /status`: Verifica o status da conexão com o WhatsApp
- `POST /send-message`: Envia uma mensagem via WhatsApp
  ```json
  {
    "phone": "5511999999999",
    "message": "Sua mensagem aqui"
  }
  ```

## Variáveis de Ambiente

- `PORT`: Porta em que a API irá rodar (default: 3000)
- `NODE_ENV`: Ambiente de execução (development/production)

## Volumes Docker

- `whatsapp_auth`: Armazena as credenciais de autenticação do WhatsApp
- `whatsapp_node_modules`: Cache das dependências do Node.js 