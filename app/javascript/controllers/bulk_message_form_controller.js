import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "messageField",
    "messagePreview", 
    "customerCheckbox",
    "selectedCount",
    "specificCustomersSection",
    "selectAllBtn",
    "clearAllBtn"
  ]

  connect() {
    console.log("Bulk message form controller connected")
    this.updatePreview()
    this.updateSelectedCount()
    this.toggleCustomerList()
  }

  // Handle message preview updates
  updatePreview() {
    if (!this.hasMessageFieldTarget || !this.hasMessagePreviewTarget) return

    const messageType = document.querySelector('input[name="message_type"]:checked')?.value || 'custom'
    const customMessage = this.messageFieldTarget.value.trim()
    
    if (!customMessage) {
      this.messagePreviewTarget.innerHTML = '<div class="text-sm text-gray-600 dark:text-gray-400 whitespace-pre-line bg-white dark:bg-gray-800 p-4 rounded border border-gray-200 dark:border-gray-600"><em>A preview da mensagem aparecerá aqui conforme você digita...</em></div>'
      return
    }
    
    let finalMessage = ''
    const customerName = 'João Silva' // Example name for preview
    
    switch(messageType) {
      case 'payment_reminder':
        finalMessage = `Olá ${customerName}!\n\nEste é um lembrete de pagamento importante.\n\n${customMessage}\n\nPara mais informações, entre em contato conosco.\n\nAtt,\nBillBuddy`
        break
      case 'general_announcement':
        finalMessage = `Olá ${customerName}!\n\n${customMessage}\n\nAtt,\nEquipe BillBuddy`
        break
      default:
        finalMessage = customMessage.replace(/\{\{nome\}\}|\{\{name\}\}/g, customerName) + '\n\nAtt,\nBillBuddy'
    }
    
    this.messagePreviewTarget.innerHTML = `<div class="text-sm text-gray-600 dark:text-gray-400 whitespace-pre-line bg-white dark:bg-gray-800 p-4 rounded border border-gray-200 dark:border-gray-600">${finalMessage}</div>`
  }

  // Handle message type changes  
  messageTypeChanged() {
    this.updatePreview()
  }

  // Handle target audience changes
  toggleCustomerList() {
    if (!this.hasSpecificCustomersSectionTarget) return

    const specificSelected = document.querySelector('input[name="target_audience"][value="specific"]')?.checked
    
    if (specificSelected) {
      this.specificCustomersSectionTarget.classList.remove('hidden')
    } else {
      this.specificCustomersSectionTarget.classList.add('hidden')
    }
  }

  // Update selected customers count
  updateSelectedCount() {
    if (!this.hasSelectedCountTarget) return

    const checkedCount = this.customerCheckboxTargets.filter(checkbox => checkbox.checked).length
    this.selectedCountTarget.textContent = checkedCount
  }

  // Select all customers
  selectAllCustomers() {
    this.customerCheckboxTargets.forEach(checkbox => {
      checkbox.checked = true
    })
    this.updateSelectedCount()
  }

  // Clear all customer selections
  clearAllCustomers() {
    this.customerCheckboxTargets.forEach(checkbox => {
      checkbox.checked = false
    })
    this.updateSelectedCount()
  }

  // Handle individual checkbox changes
  customerCheckboxChanged() {
    this.updateSelectedCount()
  }
} 