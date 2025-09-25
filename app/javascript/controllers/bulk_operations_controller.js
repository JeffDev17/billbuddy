import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    // Common bulk operation targets
    "checkbox", 
    "selectAll", 
    "selectedCount",
    
    // Appointments specific targets
    "selectAllCustomers", 
    "customerCheckbox", 
    "timeSlotsContainer", 
    "summary",
    
    // Delete specific targets
    "customerSelect", 
    "deleteButton", 
    "futureOnlyCheckbox",
    
    // Message form specific targets
    "messageField",
    "messagePreview", 
    "specificCustomersSection",
    "selectAllBtn",
    "clearAllBtn",
    
    // Payment specific targets
    "bulkActions", 
    "markAllPaid", 
    "markSelectedPaid"
  ]
  static values = { 
    type: { type: String, default: "general" }, // "appointments", "delete", "messages", "payments"
    defaultTimes: Array,
    month: String
  }

  connect() {
    this.initializeBasedOnType()
  }

  initializeBasedOnType() {
    switch (this.typeValue) {
      case "appointments":
        this.initializeAppointments()
        break
      case "delete":
        this.initializeDelete()
        break
      case "messages":
        this.initializeMessages()
        break
      case "payments":
        this.initializePayments()
        break
      default:
        this.initializeGeneral()
    }
  }

  // Appointments functionality (was bulk_appointments_controller.js)
  initializeAppointments() {
    console.log("Bulk appointments controller connected")
    this.loadDefaultTimeSlots()
    this.updateSummary()
    this.setupEventListeners()
  }

  setupEventListeners() {
    // Listen for changes to update summary
    this.element.addEventListener('change', () => {
      this.updateSummary()
    })
    this.element.addEventListener('input', () => {
      this.updateSummary()
    })
  }

  toggleAllCustomers(event) {
    const isChecked = event.target.checked
    this.customerCheckboxTargets.forEach(checkbox => {
      checkbox.checked = isChecked
    })
    this.updateSummary()
  }

  addTimeSlot() {
    const container = this.timeSlotsContainerTarget
    const timeSlotDiv = document.createElement('div')
    timeSlotDiv.className = 'flex items-center space-x-2'
    timeSlotDiv.innerHTML = `
      <input type="time" 
             name="time_slots[]" 
             class="flex-1 px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-md focus:outline-none focus:ring-2 focus:ring-indigo-500 dark:focus:ring-indigo-400 bg-white dark:bg-gray-700 text-gray-900 dark:text-gray-100"
             required>
      <button type="button" 
              data-action="click->bulk-operations#removeTimeSlot"
              class="px-2 py-2 text-red-600 dark:text-red-400 hover:text-red-800 dark:hover:text-red-200 focus:outline-none">
        ✕
      </button>
    `
    container.appendChild(timeSlotDiv)
    this.updateSummary()
  }

  removeTimeSlot(event) {
    event.target.closest('div').remove()
    this.updateSummary()
  }

  loadDefaultTimeSlots() {
    if (this.defaultTimesValue && this.defaultTimesValue.length > 0) {
      this.defaultTimesValue.forEach(time => {
        this.addTimeSlotWithValue(time)
      })
    } else {
      // Add one empty time slot if no defaults
      this.addTimeSlot()
    }
  }

  addTimeSlotWithValue(timeValue) {
    const container = this.timeSlotsContainerTarget
    const timeSlotDiv = document.createElement('div')
    timeSlotDiv.className = 'flex items-center space-x-2'
    timeSlotDiv.innerHTML = `
      <input type="time" 
             name="time_slots[]" 
             value="${timeValue}"
             class="flex-1 px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-md focus:outline-none focus:ring-2 focus:ring-indigo-500 dark:focus:ring-indigo-400 bg-white dark:bg-gray-700 text-gray-900 dark:text-gray-100"
             required>
      <button type="button" 
              data-action="click->bulk-operations#removeTimeSlot"
              class="px-2 py-2 text-red-600 dark:text-red-400 hover:text-red-800 dark:hover:text-red-200 focus:outline-none">
        ✕
      </button>
    `
    container.appendChild(timeSlotDiv)
  }

  updateSummary() {
    if (!this.hasSummaryTarget) return

    const selectedCustomers = this.customerCheckboxTargets.filter(cb => cb.checked).length
    const selectedDays = this.element.querySelectorAll('input[name="recurring_days[]"]:checked').length
    const timeSlots = this.element.querySelectorAll('input[name="time_slots[]"]').length
    const startDate = this.element.querySelector('input[name="start_date"]')?.value
    const endDate = this.element.querySelector('input[name="end_date"]')?.value
    const duration = this.element.querySelector('input[name="duration"]')?.value || 1

    let summaryText = ""

    if (selectedCustomers === 0 || selectedDays === 0 || timeSlots === 0) {
      summaryText = "Configure os parâmetros acima para ver o resumo"
    } else {
      const weeks = this.calculateWeeks(startDate, endDate)
      const totalAppointments = selectedCustomers * selectedDays * timeSlots * weeks
      const totalHours = totalAppointments * parseFloat(duration)

      summaryText = `
        🎯 ${selectedCustomers} cliente(s) × ${selectedDays} dia(s) × ${timeSlots} horário(s) × ${weeks} semana(s) = 
        <strong>${totalAppointments} compromissos</strong><br>
        ⏱️ Total de <strong>${totalHours} horas</strong> de compromissos<br>
        📅 Período: ${this.formatDate(startDate)} até ${this.formatDate(endDate)}
      `
    }

    this.summaryTarget.innerHTML = summaryText
  }

  calculateWeeks(startDate, endDate) {
    if (!startDate || !endDate) return 0
    
    const start = new Date(startDate)
    const end = new Date(endDate)
    const diffTime = Math.abs(end - start)
    const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24))
    return Math.max(1, Math.ceil(diffDays / 7))
  }

  formatDate(dateString) {
    if (!dateString) return ""
    const date = new Date(dateString)
    return date.toLocaleDateString('pt-BR')
  }

  // Delete functionality (was bulk_delete_controller.js)
  initializeDelete() {
    console.log("Bulk delete controller connected")
    this.updateDeleteButton()
  }

  customerSelectTargetConnected() {
    this.customerSelectTarget.addEventListener('change', () => {
      this.updateDeleteButton()
    })
  }

  updateDeleteButton() {
    if (!this.hasCustomerSelectTarget || !this.hasDeleteButtonTarget) return

    const selectedCustomerId = this.customerSelectTarget.value
    const selectedOption = this.customerSelectTarget.selectedOptions[0]
    const futureOnly = this.hasFutureOnlyCheckboxTarget && this.futureOnlyCheckboxTarget.checked
    
    if (selectedCustomerId && selectedOption) {
      this.deleteButtonTarget.disabled = false
      
      let appointmentCount, buttonText
      if (futureOnly) {
        appointmentCount = selectedOption.dataset.futureCount
        buttonText = `Deletar Futuros (${appointmentCount})`
      } else {
        appointmentCount = selectedOption.dataset.count
        buttonText = `Deletar Todos (${appointmentCount})`
      }
      
      this.deleteButtonTarget.textContent = buttonText
    } else {
      this.deleteButtonTarget.disabled = true
      this.deleteButtonTarget.textContent = "Deletar Todos"
    }
  }

  confirmDelete() {
    const selectedCustomerId = this.customerSelectTarget.value
    const selectedOption = this.customerSelectTarget.selectedOptions[0]
    const futureOnly = this.hasFutureOnlyCheckboxTarget && this.futureOnlyCheckboxTarget.checked
    
    if (!selectedCustomerId || !selectedOption) {
      alert("Por favor, selecione um cliente primeiro.")
      return
    }

    const customerName = selectedOption.textContent.split(' (')[0]
    let appointmentCount, confirmationMessage
    
    if (futureOnly) {
      appointmentCount = selectedOption.dataset.futureCount
      confirmationMessage = `ATENÇÃO: Esta ação vai deletar os ${appointmentCount} compromissos FUTUROS de ${customerName}.\n\n` +
                           `Compromissos passados e já realizados serão preservados.\n\n` +
                           `Esta ação não pode ser desfeita. Tem certeza?`
    } else {
      appointmentCount = selectedOption.dataset.count
      confirmationMessage = `ATENÇÃO: Esta ação vai deletar TODOS os ${appointmentCount} compromissos de ${customerName}.\n\n` +
                           `Esta ação não pode ser desfeita. Tem certeza?`
    }
    
    const confirmed = confirm(confirmationMessage)
    
    if (confirmed) {
      // Create a form and submit it
      const form = document.createElement('form')
      form.method = 'POST'
      form.action = `/appointments/bulk_delete_by_customer/${selectedCustomerId}`
      
      // Add CSRF token
      const csrfToken = document.querySelector('meta[name="csrf-token"]')?.getAttribute('content')
      if (csrfToken) {
        const csrfInput = document.createElement('input')
        csrfInput.type = 'hidden'
        csrfInput.name = 'authenticity_token'
        csrfInput.value = csrfToken
        form.appendChild(csrfInput)
      }
      
      // Add method override for DELETE
      const methodInput = document.createElement('input')
      methodInput.type = 'hidden'
      methodInput.name = '_method'
      methodInput.value = 'delete'
      form.appendChild(methodInput)
      
      // Add future_only parameter if checkbox is checked
      if (futureOnly) {
        const futureOnlyInput = document.createElement('input')
        futureOnlyInput.type = 'hidden'
        futureOnlyInput.name = 'future_only'
        futureOnlyInput.value = 'true'
        form.appendChild(futureOnlyInput)
      }
      
      document.body.appendChild(form)
      form.submit()
    }
  }

  // Message form functionality (was bulk_message_form_controller.js)
  initializeMessages() {
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

  // Payments functionality (was bulk_payment_controller.js)
  initializePayments() {
    this.updateBulkActions()
  }

  toggleSelectAll() {
    const isChecked = this.selectAllTarget.checked
    this.checkboxTargets.forEach(checkbox => {
      checkbox.checked = isChecked
    })
    this.updateBulkActions()
  }

  toggleCheckbox() {
    this.updateSelectAllState()
    this.updateBulkActions()
  }

  updateSelectAllState() {
    if (!this.hasSelectAllTarget) return

    const totalCheckboxes = this.checkboxTargets.length
    const checkedCheckboxes = this.selectedCheckboxes.length

    if (checkedCheckboxes === 0) {
      this.selectAllTarget.checked = false
      this.selectAllTarget.indeterminate = false
    } else if (checkedCheckboxes === totalCheckboxes) {
      this.selectAllTarget.checked = true
      this.selectAllTarget.indeterminate = false
    } else {
      this.selectAllTarget.checked = false
      this.selectAllTarget.indeterminate = true
    }
  }

  updateBulkActions() {
    const selectedCount = this.selectedCheckboxes.length
    const totalCount = this.checkboxTargets.length
    
    // Update counter
    if (this.hasSelectedCountTarget) {
      this.selectedCountTarget.textContent = selectedCount
    }
    
    // Show/hide bulk actions
    if (this.hasBulkActionsTarget) {
      this.bulkActionsTarget.style.display = selectedCount > 0 ? 'flex' : 'none'
    }
    
    // Update button states
    if (this.hasMarkSelectedPaidTarget) {
      this.markSelectedPaidTarget.disabled = selectedCount === 0
    }
    
    if (this.hasMarkAllPaidTarget) {
      this.markAllPaidTarget.disabled = totalCount === 0
    }
  }

  async markSelectedAsPaid(event) {
    event.preventDefault()
    
    const selectedCustomers = this.selectedCheckboxes
    if (selectedCustomers.length === 0) {
      alert('Selecione pelo menos um cliente.')
      return
    }

    const month = this.monthValue
    if (!month) {
      alert('Mês não especificado.')
      return
    }

    if (!confirm(`Marcar ${selectedCustomers.length} cliente(s) como pago(s)?`)) {
      return
    }

    this.setLoading(true)
    
    try {
      await this.processBulkPayments(selectedCustomers, month)
      window.location.reload() // Refresh to show updated status
    } catch (error) {
      alert('Erro ao processar pagamentos: ' + error.message)
    } finally {
      this.setLoading(false)
    }
  }

  async markAllAsPaid(event) {
    event.preventDefault()
    
    const pendingCustomers = this.pendingCheckboxes
    if (pendingCustomers.length === 0) {
      alert('Nenhum cliente com pagamento pendente.')
      return
    }

    const month = this.monthValue
    if (!month) {
      alert('Mês não especificado.')
      return
    }

    if (!confirm(`Marcar TODOS os ${pendingCustomers.length} cliente(s) pendentes como pagos?`)) {
      return
    }

    this.setLoading(true)
    
    try {
      await this.processBulkPayments(pendingCustomers, month)
      window.location.reload() // Refresh to show updated status
    } finally {
      this.setLoading(false)
    }
  }

  async processBulkPayments(checkboxes, month) {
    const customerIds = checkboxes.map(checkbox => checkbox.dataset.customerId)
    
    const response = await fetch('/payments/bulk_mark_paid', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
      },
      body: JSON.stringify({
        customer_ids: customerIds,
        month: month
      })
    })
    
    if (!response.ok) {
      const data = await response.json()
      throw new Error(data.message || 'Erro desconhecido')
    }
    
    return response.json()
  }

  setLoading(isLoading) {
    if (this.hasMarkSelectedPaidTarget) {
      this.markSelectedPaidTarget.disabled = isLoading
      this.markSelectedPaidTarget.textContent = isLoading ? '⏳ Processando...' : '✅ Marcar Selecionados'
    }
    
    if (this.hasMarkAllPaidTarget) {
      this.markAllPaidTarget.disabled = isLoading
      this.markAllPaidTarget.textContent = isLoading ? '⏳ Processando...' : '💰 Marcar Todos como Pagos'
    }
  }

  // General functionality
  initializeGeneral() {
    this.updateSelectedCount()
  }

  // Update selected count (shared between controllers)
  updateSelectedCount() {
    if (!this.hasSelectedCountTarget) return

    const checkedCount = this.customerCheckboxTargets.filter(checkbox => checkbox.checked).length
    this.selectedCountTarget.textContent = checkedCount
  }

  // Handle individual checkbox changes (shared functionality)
  customerCheckboxChanged() {
    this.updateSelectedCount()
    if (this.typeValue === "payments") {
      this.updateSelectAllState()
      this.updateBulkActions()
    }
  }

  // Getters for payment functionality
  get selectedCheckboxes() {
    return this.checkboxTargets.filter(checkbox => checkbox.checked)
  }

  get pendingCheckboxes() {
    return this.checkboxTargets.filter(checkbox => {
      const status = checkbox.dataset.currentStatus
      return status === 'pending'
    })
  }
}
