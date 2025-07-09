import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["amount", "message", "preview", "loadTemplate"]

  connect() {
    // Carregar template inicial se não houver mensagem
    if (!this.messageTarget.value.trim()) {
      this.loadDefaultTemplate()
    }
    this.updatePreview()
  }

  updatePreview() {
    let message = this.messageTarget.value.trim()
    const amount = this.amountTarget.value || '0,00'
    
    if (!message) {
      this.previewTarget.innerHTML = '<em class="text-gray-400">Digite uma mensagem para ver o preview...</em>'
      return
    }

    // Substituir {VALOR} pelo valor real
    const formattedAmount = this.formatCurrency(parseFloat(amount) || 0)
    const finalMessage = message.replace(/{VALOR}/gi, formattedAmount)
    this.previewTarget.textContent = finalMessage
  }

  loadDefaultTemplate() {
    const customerName = this.data.get("customerName") || "[Nome do Cliente]"
    
    const template = `Olá ${customerName}!

Este é um lembrete de pagamento no valor de {VALOR}.

Por favor, entre em contato para regularizar sua situação.

Para mais informações, responda esta mensagem ou entre em contato conosco.

Obrigado pela sua atenção!

Att,
BillBuddy`

    this.messageTarget.value = template
    this.updatePreview()
    this.messageTarget.focus()
  }

  formatAmount() {
    if (this.amountTarget.value) {
      this.amountTarget.value = parseFloat(this.amountTarget.value).toFixed(2)
      this.updatePreview()
    }
  }

  formatCurrency(value) {
    return `R$ ${value.toFixed(2).replace('.', ',')}`
  }
} 