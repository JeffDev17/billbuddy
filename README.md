# BillBuddy 💼

Sistema completo de gestão para profissionais autônomos, desenvolvido em Ruby on Rails. Gerencie clientes, agendamentos, pagamentos e métricas de negócio com integrações WhatsApp e Google Calendar.

## 🎭 Demo Online
**🔗 Demo:** https://billbuddy-demo.onrender.com  
**Login:** demo@billbuddy.com / demo123456

## ✨ Funcionalidades Principais

### 👥 Gestão de Clientes
- Cadastro completo com dados pessoais e financeiros
- Sistema de créditos e assinaturas mensais
- Controle de status (ativo, inativo, em espera)
- Importação/exportação em CSV
- Histórico de pagamentos e agendamentos
- Lembretes de aniversário

### 📅 Sistema de Agendamentos
- Criação e edição de compromissos
- Geração automática de agendamentos mensais
- Sincronização com Google Calendar
- Controle de status (agendado, concluído, cancelado)
- Sistema de reagendamento
- Lembretes automáticos via WhatsApp

### 💰 Gestão Financeira
- Controle de pagamentos com múltiplas modalidades
- Checklist mensal de cobrança
- Relatórios de receita e métricas
- Sistema de créditos e débitos
- Controle de taxas personalizadas por cliente

### 📊 Dashboard e Relatórios
- Métricas de negócio em tempo real
- Análise de performance semanal/mensal
- Indicadores de saúde do negócio
- Gráficos de receita e produtividade
- Relatórios de clientes e agendamentos

### 🔗 Integrações
- **WhatsApp:** Notificações automáticas e lembretes
- **Google Calendar:** Sincronização bidirecional
- **PWA:** Aplicativo instalável no mobile

## 🛠️ Stack Tecnológica

### Backend
- **Ruby 3.3.8** - Linguagem principal
- **Rails 7.2.2** - Framework web
- **PostgreSQL** - Banco de dados
- **Sidekiq** - Processamento em background
- **Redis** - Cache e filas

### Frontend
- **TailwindCSS** - Framework CSS
- **Stimulus** - JavaScript framework
- **Turbo** - Navegação SPA
- **Chart.js** - Gráficos e visualizações
- **FullCalendar** - Calendário interativo

### DevOps
- **Docker** - Containerização
- **Render** - Deploy em produção
- **PWA** - Progressive Web App

## 🚀 Instalação e Configuração

### Pré-requisitos
- Ruby 3.3.8
- PostgreSQL 14+
- Redis
- Node.js 18+

### Setup Local
```bash
# Clone o repositório
git clone https://github.com/seu-usuario/billbuddy.git
cd billbuddy

# Instale dependências
bundle install
npm install

# Configure o banco de dados
rails db:create
rails db:migrate
rails db:seed

# Inicie os serviços
rails server
```

### Variáveis de Ambiente
```bash
# Google Calendar
GOOGLE_CLIENT_ID=your_client_id
GOOGLE_CLIENT_SECRET=your_client_secret

# WhatsApp API
WHATSAPP_API_URL=your_whatsapp_api_url
WHATSAPP_API_TOKEN=your_token

# Redis
REDIS_URL=redis://localhost:6379/0
```

## 📱 Funcionalidades Mobile

- **PWA** instalável no smartphone
- Interface responsiva otimizada
- Notificações push
- Sincronização offline

## 🔧 Arquitetura

### Padrões Utilizados
- **Service Objects** - Lógica de negócio isolada
- **Background Jobs** - Processamento assíncrono
- **API Integration** - Serviços externos
- **Multi-tenancy** - Isolamento por usuário

### Principais Services
- `PaymentManagementService` - Gestão financeira
- `GoogleCalendarSyncService` - Sincronização de calendário
- `WhatsAppNotificationService` - Notificações
- `AppointmentCompletionService` - Gestão de agendamentos

## 📈 Métricas e Analytics

- Taxa de conclusão de agendamentos
- Receita por período
- Análise de crescimento
- Indicadores de retenção de clientes
- Performance por dia da semana

## 🎯 Casos de Uso

Ideal para:
- **Professores particulares** - Agendamentos de aulas individuais
- **Consultores** - Sessões de consultoria  
- **Terapeutas** - Atendimentos regulares
- **Coaches** - Sessões de coaching
- **Freelancers** - Controle de projetos e reuniões

## 📄 Licença

MIT License - Veja o arquivo LICENSE para detalhes.

---

*Projeto desenvolvido como demonstração de habilidades Full-Stack Ruby on Rails*