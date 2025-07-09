require "csv"

# Dados dos clientes reais
clients_data = [
  { name: "Beatriz Guedes", monthly_amount: 340.00, due_day: 5, monthly_hours: 4, hourly_rate: 85.00 },
  { name: "Cadu", monthly_amount: 590.00, due_day: 5, monthly_hours: 8, hourly_rate: 73.75 },
  { name: "Giovanna Pratali", monthly_amount: 340.00, due_day: 5, monthly_hours: 4, hourly_rate: 85.00 },
  { name: "Igor Lopes", monthly_amount: 460.00, due_day: 5, monthly_hours: 8, hourly_rate: 57.50 },
  { name: "Luciana Zollman", monthly_amount: 500.00, due_day: 5, monthly_hours: 8, hourly_rate: 62.50 },
  { name: "Marcos Matheus", monthly_amount: 340.00, due_day: 5, monthly_hours: 4, hourly_rate: 85.00 },
  { name: "Nathan", monthly_amount: 340.00, due_day: 5, monthly_hours: 4, hourly_rate: 85.00 },
  { name: "Sol / Luiggi", monthly_amount: 565.00, due_day: 5, monthly_hours: 8, hourly_rate: 70.63 },
  { name: "Victor Marques", monthly_amount: 340.00, due_day: 5, monthly_hours: 4, hourly_rate: 85.00 },
  { name: "Wilton Cunha", monthly_amount: 340.00, due_day: 5, monthly_hours: 4, hourly_rate: 85.00 },
  { name: "Rafaely Santana", monthly_amount: 340.00, due_day: 5, monthly_hours: 4, hourly_rate: 85.00 },
  { name: "Maria J\u00FAlia", monthly_amount: 340.00, due_day: 10, monthly_hours: 4, hourly_rate: 85.00 },
  { name: "Fabiana Poveda", monthly_amount: 340.00, due_day: 15, monthly_hours: 4, hourly_rate: 85.00 },
  { name: "Gen\u00E9sio Antonio", monthly_amount: 340.00, due_day: 15, monthly_hours: 4, hourly_rate: 85.00 },
  { name: "Ingrid Baptista", monthly_amount: 610.00, due_day: 15, monthly_hours: 8, hourly_rate: 76.25 },
  { name: "Caio e Maria", monthly_amount: 1050.00, due_day: 20, monthly_hours: 8, hourly_rate: 131.25 },
  { name: "Cris AUS", monthly_amount: 340.00, due_day: 20, monthly_hours: 4, hourly_rate: 85.00 },
  { name: "Gabriel Oliveira", monthly_amount: 340.00, due_day: 20, monthly_hours: 4, hourly_rate: 85.00 },
  { name: "Jonathan AUS", monthly_amount: 340.00, due_day: 20, monthly_hours: 4, hourly_rate: 85.00 },
  { name: "Luciano Bonetti", monthly_amount: 610.00, due_day: 20, monthly_hours: 8, hourly_rate: 76.25 },
  { name: "Lucas Alves", monthly_amount: 340.00, due_day: 25, monthly_hours: 4, hourly_rate: 85.00 },
  { name: "Juliano Pereira", monthly_amount: 610.00, due_day: 30, monthly_hours: 8, hourly_rate: 76.25 },
  { name: "Raphael Bernoldi", monthly_amount: 1152.00, due_day: 30, monthly_hours: 20, hourly_rate: 57.60 },
  { name: "Tiago Fadel", monthly_amount: 340.00, due_day: 30, monthly_hours: 4, hourly_rate: 85.00 },
  { name: "Vinicius Necker", monthly_amount: 287.00, due_day: 30, monthly_hours: 4, hourly_rate: 71.75 }
]

puts "🎯 Gerando CSV com #{clients_data.count} clientes..."

# Gerar CSV no formato compatível com o app
CSV.open("clientes_reais.csv", "w", headers: true) do |csv|
  # Cabeçalhos compatíveis com o sistema
  csv << [ "nome", "email", "telefone", "status", "tipo_plano", "preco_personalizado" ]

  clients_data.each do |client|
    csv << [
      client[:name],
      "", # email vazio
      "", # telefone vazio
      "active", # status ativo
      "subscription", # tipo de plano assinatura
      client[:hourly_rate] # preço personalizado por hora
    ]
  end
end

puts "✅ Arquivo 'clientes_reais.csv' gerado com sucesso!"
puts "📋 O arquivo contém:"
puts "   • #{clients_data.count} clientes"
puts "   • Preços personalizados por hora"
puts "   • Status ativo para todos"
puts "   • Tipo 'subscription' para todos"
puts ""
puts "📝 Para usar:"
puts "   1. Copie o arquivo clientes_reais.csv"
puts "   2. Vá para Clientes > Importar CSV"
puts "   3. Selecione o arquivo e importe"
puts ""

# Também gerar um arquivo separado com os dados das assinaturas para referência
CSV.open("assinaturas_dados.csv", "w", headers: true) do |csv|
  csv << [ "cliente", "valor_mensal", "dia_vencimento", "horas_mensais", "preco_hora" ]

  clients_data.each do |client|
    csv << [
      client[:name],
      client[:monthly_amount],
      client[:due_day],
      client[:monthly_hours],
      client[:hourly_rate]
    ]
  end
end

puts "📊 Arquivo 'assinaturas_dados.csv' gerado para referência!"
puts "   (contém os dados detalhados das assinaturas)"
