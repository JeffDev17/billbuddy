# BillBuddy

BillBuddy é um sistema de gerenciamento de cobranças recorrentes para profissionais autônomos e pequenos negócios.

## Funcionalidades

- Gerenciamento de clientes/alunos
- Sistema de créditos (pacotes de horas)
- Cobranças recorrentes (mensalidades)
- Controle de aulas e agendamentos
- Notificações e lembretes

## Métricas e Analytics

O sistema inclui um dashboard completo de métricas utilizando a gem [Chartkick](https://chartkick.com/) para visualização de dados:

### Gráficos Disponíveis:
- **Distribuição de Status**: Gráfico de pizza mostrando aulas concluídas, agendadas, canceladas e faltas
- **Tendência Mensal**: Linha temporal dos últimos 6 meses de performance
- **Performance Semanal**: Colunas mostrando dados das últimas 4 semanas
- **Evolução do Faturamento**: Gráfico de área com evolução dos ganhos
- **Top 5 Clientes**: Ranking dos clientes por faturamento
- **Dias Mais Ocupados**: Distribuição de aulas por dia da semana

### Métricas Principais:
- Ganhos do mês vs meta projetada
- Ticket médio por aula
- Taxa de realização e cancelamento
- Total de horas trabalhadas
- Status de sincronização com Google Calendar

## Requisitos

- Ruby 3.2.x
- Rails 7.x
- PostgreSQL

## Instalação

1. Clone o repositório
2. Execute `bundle install`
3. Configure o banco de dados: `rails db:create db:migrate`
4. Inicie o servidor: `rails server`

## Desenvolvimento

Este projeto segue as convenções padrão do Rails e utiliza:
- TailwindCSS para estilização
- RSpec para testes
- Devise para autenticação

## Licença

[Escolha uma licença apropriada]