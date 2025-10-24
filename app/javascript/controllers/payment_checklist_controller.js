import { Controller } from "@hotwired/stimulus"

// Consolidated controller for payment checklist - handles status updates, filters, and amount editing
export default class extends Controller {
  static targets = [
    "statusSelect",
    "paidCount",
    "cancelledCount", 
    "pendingCount",
    "totalReceived",
    "totalCancelled",
    "totalPending",
    "filterButton",
    "customerRow",
    "overdueCount",
    "pendingColumn",
    "paidColumn",
    "cancelledColumn"
  ]

  connect() {
    console.log("Payment checklist controller connected")
    this.activeFilter = 'all'
  }

  // ==================== STATUS UPDATE METHODS ====================

  async changeStatus(event) {
    event.preventDefault()
    const button = event.currentTarget
    const customerId = button.dataset.customerId
    const month = button.dataset.month
    const newStatus = button.dataset.newStatus
    const oldStatus = button.dataset.currentStatus
    
    if (newStatus === oldStatus) return
    
    if (newStatus === 'paid') {
      this.showDatePickerModalForCard(customerId, month, oldStatus, newStatus)
      return
    }
    
    this.performCardStatusUpdate(customerId, month, oldStatus, newStatus)
  }

  async updateStatus(event) {
    const select = event.target
    const customerId = select.dataset.customerId
    const month = select.dataset.month
    const newStatus = select.value
    const oldStatus = select.dataset.currentStatus
    
    if (newStatus === oldStatus) return
    
    if (newStatus === 'paid') {
      this.showDatePickerModal(select, customerId, month, oldStatus, newStatus)
      return
    }
    
    this.performStatusUpdate(select, customerId, month, oldStatus, newStatus)
  }

  showDatePickerModal(select, customerId, month, oldStatus, newStatus) {
    select.value = oldStatus
    
    const monthDate = new Date(`${month}-01`)
    const today = new Date()
    
    const modal = document.createElement('div')
    modal.className = 'fixed inset-0 bg-gray-600 bg-opacity-50 dark:bg-gray-900 dark:bg-opacity-70 flex items-center justify-center z-50'
    modal.innerHTML = `
      <div class="bg-white dark:bg-gray-800 rounded-lg shadow-xl p-6 max-w-md w-full mx-4">
        <h3 class="text-lg font-medium text-gray-900 dark:text-gray-100 mb-4">Escolher Data do Pagamento</h3>
        <p class="text-sm text-gray-600 dark:text-gray-400 mb-4">Selecione a data em que o pagamento foi recebido:</p>
        
        <div class="mb-4">
          <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">Data do Pagamento</label>
          <input type="date" id="customPaymentDate" 
                 value="${monthDate.toISOString().split('T')[0]}"
                 class="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-md focus:outline-none focus:ring-2 focus:ring-indigo-500 bg-white dark:bg-gray-700 text-gray-900 dark:text-gray-100">
        </div>
        
        <div class="flex space-x-2 mb-4">
          <button onclick="document.getElementById('customPaymentDate').value = '${monthDate.toISOString().split('T')[0]}'" 
                  class="flex-1 px-3 py-2 text-xs bg-blue-100 dark:bg-blue-900 text-blue-800 dark:text-blue-200 rounded hover:bg-blue-200 dark:hover:bg-blue-800">
            📅 Usar dia 01 do mês
          </button>
          <button onclick="document.getElementById('customPaymentDate').value = '${today.toISOString().split('T')[0]}'" 
                  class="flex-1 px-3 py-2 text-xs bg-green-100 dark:bg-green-900 text-green-800 dark:text-green-200 rounded hover:bg-green-200 dark:hover:bg-green-800">
            ✅ Usar data de hoje
          </button>
        </div>
        
        <div class="flex justify-end space-x-2">
          <button id="cancelDatePicker" class="px-4 py-2 bg-gray-500 text-white rounded hover:bg-gray-600 dark:bg-gray-600 dark:hover:bg-gray-700">
            Cancelar
          </button>
          <button id="confirmDatePicker" class="px-4 py-2 bg-indigo-600 text-white rounded hover:bg-indigo-700 dark:bg-indigo-700 dark:hover:bg-indigo-800">
            Confirmar
          </button>
        </div>
      </div>
    `
    
    document.body.appendChild(modal)
    
    modal.querySelector('#confirmDatePicker').addEventListener('click', () => {
      const customDate = modal.querySelector('#customPaymentDate').value
      document.body.removeChild(modal)
      this.performStatusUpdate(select, customerId, month, oldStatus, newStatus, customDate)
    })
    
    modal.querySelector('#cancelDatePicker').addEventListener('click', () => {
      document.body.removeChild(modal)
    })
    
    modal.addEventListener('click', (e) => {
      if (e.target === modal) {
        document.body.removeChild(modal)
      }
    })
  }

  async performStatusUpdate(select, customerId, month, oldStatus, newStatus, customDate = null) {
    select.disabled = true
    select.style.opacity = '0.6'
    
    try {
      const body = {
        customer_id: customerId,
        month: month,
        status: newStatus
      }
      
      if (customDate) {
        body.custom_date = customDate
      }
      
      const response = await fetch('/payments/update_payment_status', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
        },
        body: JSON.stringify(body)
      })
      
      const data = await response.json()
      
      if (data.success) {
        select.value = newStatus
        select.dataset.currentStatus = newStatus
        
        this.updateCounts(oldStatus, newStatus)
        this.updateRowStyling(customerId, newStatus)
        this.showToast(`Status alterado para: ${this.getStatusText(newStatus)}`, 'success')
        this.updateTotals()
        
        const currentSort = new URLSearchParams(window.location.search).get('sort_by')
        if (currentSort === 'payment_status' || currentSort === 'payment_status_reverse') {
          setTimeout(() => {
            window.location.reload()
          }, 1000)
        }
      } else {
        select.value = oldStatus
        this.showToast(data.message || 'Erro ao atualizar status', 'error')
      }
    } catch (error) {
      console.error('Error:', error)
      select.value = oldStatus
      this.showToast('Erro de conexão', 'error')
    } finally {
      select.disabled = false
      select.style.opacity = '1'
    }
  }

  updateCounts(oldStatus, newStatus) {
    if (oldStatus !== 'paid' && newStatus === 'paid') {
      this.incrementCount('paidCount')
    } else if (oldStatus === 'paid' && newStatus !== 'paid') {
      this.decrementCount('paidCount')
    }
    
    if (oldStatus !== 'cancelled' && newStatus === 'cancelled') {
      this.incrementCount('cancelledCount')
    } else if (oldStatus === 'cancelled' && newStatus !== 'cancelled') {
      this.decrementCount('cancelledCount')
    }
    
    if (oldStatus !== 'pending' && newStatus === 'pending') {
      this.incrementCount('pendingCount')
    } else if (oldStatus === 'pending' && newStatus !== 'pending') {
      this.decrementCount('pendingCount')
    }
  }

  incrementCount(targetName) {
    const target = this[`${targetName}Target`]
    if (target) {
      const currentValue = parseInt(target.textContent) || 0
      target.textContent = currentValue + 1
    }
  }

  decrementCount(targetName) {
    const target = this[`${targetName}Target`]
    if (target) {
      const currentValue = parseInt(target.textContent) || 0
      target.textContent = Math.max(0, currentValue - 1)
    }
  }

  async updateTotals() {
    try {
      const month = this.statusSelectTargets[0]?.dataset.month
      if (!month) return
      
      const response = await fetch(`/payments/monthly_totals?month=${month}`, {
        headers: {
          'Accept': 'application/json'
        }
      })
      
      if (response.ok) {
        const data = await response.json()
        
        if (this.hasTotalReceivedTarget) {
          this.totalReceivedTarget.textContent = `R$ ${data.total_received.toFixed(2)}`
        }
        if (this.hasTotalCancelledTarget) {
          this.totalCancelledTarget.textContent = `R$ ${data.total_cancelled.toFixed(2)}`
        }
        if (this.hasTotalPendingTarget) {
          this.totalPendingTarget.textContent = `R$ ${data.total_pending.toFixed(2)}`
        }
      }
    } catch (error) {
      console.error('Error updating totals:', error)
    }
  }

  updateRowStyling(customerId, newStatus) {
    const customerRow = document.querySelector(`[data-customer-id="${customerId}"]`)
    if (!customerRow) return
    
    customerRow.classList.remove(
      'bg-green-50', 'dark:bg-green-900/10', 'border-green-400',
      'bg-yellow-50', 'dark:bg-yellow-900/10', 'border-yellow-400', 
      'bg-red-50', 'dark:bg-red-900/10', 'border-red-400'
    )
    
    switch(newStatus) {
      case 'paid':
        customerRow.classList.add('bg-green-50', 'dark:bg-green-900/10', 'border-green-400')
        break
      case 'cancelled':
        customerRow.classList.add('bg-yellow-50', 'dark:bg-yellow-900/10', 'border-yellow-400')
        break
      case 'pending':
        customerRow.classList.add('bg-red-50', 'dark:bg-red-900/10', 'border-red-400')
        break
    }
  }

  // ==================== FILTER METHODS ====================

  filterAll(event) {
    this.setActiveFilter(event.currentTarget, 'all')
    this.showAllRows()
  }

  filterPaid(event) {
    this.setActiveFilter(event.currentTarget, 'paid')
    this.filterByStatus('paid')
  }

  filterPending(event) {
    this.setActiveFilter(event.currentTarget, 'pending')
    this.filterByStatus('pending')
  }

  filterOverdue(event) {
    this.setActiveFilter(event.currentTarget, 'overdue')
    this.filterOverdueCustomers()
  }

  setActiveFilter(button, filter) {
    this.filterButtonTargets.forEach(btn => {
      btn.classList.remove('active', 'ring-2', 'ring-offset-2')
      btn.classList.remove('ring-green-500', 'ring-yellow-500', 'ring-red-500', 'ring-gray-500')
    })

    button.classList.add('active', 'ring-2', 'ring-offset-2')
    
    if (filter === 'paid') {
      button.classList.add('ring-green-500')
    } else if (filter === 'pending') {
      button.classList.add('ring-yellow-500')
    } else if (filter === 'overdue') {
      button.classList.add('ring-red-500')
    } else {
      button.classList.add('ring-gray-500')
    }

    this.activeFilter = filter
  }

  showAllRows() {
    this.customerRowTargets.forEach(row => {
      row.style.display = ''
    })
  }

  filterByStatus(status) {
    this.customerRowTargets.forEach(row => {
      const rowStatus = row.dataset.status
      
      if (status === 'pending') {
        row.style.display = (rowStatus === 'pending' || !rowStatus) ? '' : 'none'
      } else {
        row.style.display = (rowStatus === status) ? '' : 'none'
      }
    })
  }

  filterOverdueCustomers() {
    this.customerRowTargets.forEach(row => {
      const isOverdue = row.dataset.isOverdue === 'true'
      row.style.display = isOverdue ? '' : 'none'
    })
  }

  // ==================== AMOUNT EDITING METHODS ====================

  editAmount(event) {
    const customerId = event.currentTarget.dataset.customerId
    const container = document.querySelector(`[data-customer-id="${customerId}"] .payment-amount-container`)
    const displayDiv = container.querySelector('.amount-display')
    const editDiv = container.querySelector('.amount-edit')
    const input = editDiv.querySelector('input')
    
    displayDiv.classList.add('hidden')
    editDiv.classList.remove('hidden')
    input.focus()
    input.select()
  }

  async saveAmount(event) {
    const customerId = event.currentTarget.dataset.customerId
    const container = document.querySelector(`[data-customer-id="${customerId}"] .payment-amount-container`)
    const displayDiv = container.querySelector('.amount-display')
    const editDiv = container.querySelector('.amount-edit')
    const input = editDiv.querySelector('input')
    const newAmount = parseFloat(input.value)
    
    if (isNaN(newAmount) || newAmount <= 0) {
      this.showToast('Por favor, insira um valor válido', 'error')
      input.focus()
      return
    }
    
    const month = document.querySelector('[data-payment-checklist-target="statusSelect"]')?.dataset.month
    
    try {
      const response = await fetch('/payments/update_payment_amount', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
        },
        body: JSON.stringify({
          customer_id: customerId,
          month: month,
          amount: newAmount
        })
      })
      
      const data = await response.json()
      
      if (data.success) {
        const amountSpan = displayDiv.querySelector('.amount-value')
        amountSpan.textContent = newAmount.toFixed(2)
        
        const editIndicator = displayDiv.querySelector('.text-blue-600')
        if (data.is_manual_override && !editIndicator) {
          amountSpan.insertAdjacentHTML('afterend', ' <span class="text-blue-600 dark:text-blue-400 text-[8px]">✏️</span>')
        }
        
        editDiv.classList.add('hidden')
        displayDiv.classList.remove('hidden')
        
        this.showToast('Valor atualizado com sucesso!', 'success')
      } else {
        this.showToast('Erro ao atualizar valor: ' + data.message, 'error')
        input.focus()
      }
    } catch (error) {
      console.error('Error:', error)
      this.showToast('Erro ao atualizar valor', 'error')
      input.focus()
    }
  }

  handleAmountKeypress(event) {
    if (event.key === 'Enter') {
      event.preventDefault()
      this.saveAmount(event)
    } else if (event.key === 'Escape') {
      const customerId = event.currentTarget.dataset.customerId
      const container = document.querySelector(`[data-customer-id="${customerId}"] .payment-amount-container`)
      const displayDiv = container.querySelector('.amount-display')
      const editDiv = container.querySelector('.amount-edit')
      
      editDiv.classList.add('hidden')
      displayDiv.classList.remove('hidden')
    }
  }

  // ==================== KANBAN CARD METHODS ====================

  showDatePickerModalForCard(customerId, month, oldStatus, newStatus) {
    const monthDate = new Date(`${month}-01`)
    const today = new Date()
    
    const modal = document.createElement('div')
    modal.className = 'fixed inset-0 bg-gray-600 bg-opacity-50 dark:bg-gray-900 dark:bg-opacity-70 flex items-center justify-center z-50'
    modal.innerHTML = `
      <div class="bg-white dark:bg-gray-800 rounded-lg shadow-xl p-6 max-w-md w-full mx-4">
        <h3 class="text-lg font-medium text-gray-900 dark:text-gray-100 mb-4">Escolher Data do Pagamento</h3>
        <p class="text-sm text-gray-600 dark:text-gray-400 mb-4">Selecione a data em que o pagamento foi recebido:</p>
        
        <div class="mb-4">
          <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">Data do Pagamento</label>
          <input type="date" id="customPaymentDate" 
                 value="${monthDate.toISOString().split('T')[0]}"
                 class="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-md focus:outline-none focus:ring-2 focus:ring-indigo-500 bg-white dark:bg-gray-700 text-gray-900 dark:text-gray-100">
        </div>
        
        <div class="flex space-x-2 mb-4">
          <button onclick="document.getElementById('customPaymentDate').value = '${monthDate.toISOString().split('T')[0]}'" 
                  class="flex-1 px-3 py-2 text-xs bg-blue-100 dark:bg-blue-900 text-blue-800 dark:text-blue-200 rounded hover:bg-blue-200 dark:hover:bg-blue-800">
            📅 Usar dia 01 do mês
          </button>
          <button onclick="document.getElementById('customPaymentDate').value = '${today.toISOString().split('T')[0]}'" 
                  class="flex-1 px-3 py-2 text-xs bg-green-100 dark:bg-green-900 text-green-800 dark:text-green-200 rounded hover:bg-green-200 dark:hover:bg-green-800">
            ✅ Usar data de hoje
          </button>
        </div>
        
        <div class="flex justify-end space-x-2">
          <button id="cancelDatePicker" class="px-4 py-2 bg-gray-500 text-white rounded hover:bg-gray-600 dark:bg-gray-600 dark:hover:bg-gray-700">
            Cancelar
          </button>
          <button id="confirmDatePicker" class="px-4 py-2 bg-indigo-600 text-white rounded hover:bg-indigo-700 dark:bg-indigo-700 dark:hover:bg-indigo-800">
            Confirmar
          </button>
        </div>
      </div>
    `
    
    document.body.appendChild(modal)
    
    modal.querySelector('#confirmDatePicker').addEventListener('click', () => {
      const customDate = modal.querySelector('#customPaymentDate').value
      document.body.removeChild(modal)
      this.performCardStatusUpdate(customerId, month, oldStatus, newStatus, customDate)
    })
    
    modal.querySelector('#cancelDatePicker').addEventListener('click', () => {
      document.body.removeChild(modal)
    })
    
    modal.addEventListener('click', (e) => {
      if (e.target === modal) {
        document.body.removeChild(modal)
      }
    })
  }

  async performCardStatusUpdate(customerId, month, oldStatus, newStatus, customDate = null) {
    try {
      const body = {
        customer_id: customerId,
        month: month,
        status: newStatus
      }
      
      if (customDate) {
        body.custom_date = customDate
      }
      
      const response = await fetch('/payments/update_payment_status', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
        },
        body: JSON.stringify(body)
      })
      
      const data = await response.json()
      
      if (data.success) {
        // Move card between columns
        this.moveCardBetweenColumns(customerId, oldStatus, newStatus)
        
        // Update counts
        this.updateCounts(oldStatus, newStatus)
        this.updateTotals()
        
        this.showToast(`✅ ${newStatus === 'paid' ? 'Pago' : newStatus === 'cancelled' ? 'Cancelado' : 'Pendente'}!`, 'success')
      } else {
        this.showToast(data.message || 'Erro ao atualizar status', 'error')
      }
    } catch (error) {
      console.error('Error:', error)
      this.showToast('Erro de conexão', 'error')
    }
  }

  moveCardBetweenColumns(customerId, oldStatus, newStatus) {
    const card = document.querySelector(`[data-customer-id="${customerId}"][data-status="${oldStatus}"]`)
    if (!card) return
    
    // Update card's data-status attribute
    card.dataset.status = newStatus
    
    // Update button states in the card
    const buttons = card.querySelectorAll('button[data-action="click->payment-checklist#changeStatus"]')
    buttons.forEach(btn => {
      btn.dataset.currentStatus = newStatus
      const btnStatus = btn.dataset.newStatus
      
      // Reset all button styles
      btn.classList.remove(
        'bg-yellow-200', 'dark:bg-yellow-800', 'text-yellow-900', 'dark:text-yellow-100',
        'bg-green-200', 'dark:bg-green-800', 'text-green-900', 'dark:text-green-100',
        'bg-gray-300', 'dark:bg-gray-600', 'text-gray-900', 'dark:text-gray-100',
        'font-bold'
      )
      btn.classList.add('bg-gray-100', 'dark:bg-gray-700', 'text-gray-600', 'dark:text-gray-400')
      
      // Highlight active button
      if (btnStatus === newStatus) {
        btn.classList.remove('bg-gray-100', 'dark:bg-gray-700', 'text-gray-600', 'dark:text-gray-400')
        if (newStatus === 'pending') {
          btn.classList.add('bg-yellow-200', 'dark:bg-yellow-800', 'text-yellow-900', 'dark:text-yellow-100', 'font-bold')
        } else if (newStatus === 'paid') {
          btn.classList.add('bg-green-200', 'dark:bg-green-800', 'text-green-900', 'dark:text-green-100', 'font-bold')
        } else if (newStatus === 'cancelled') {
          btn.classList.add('bg-gray-300', 'dark:bg-gray-600', 'text-gray-900', 'dark:text-gray-100', 'font-bold')
        }
      }
    })
    
    // Move to appropriate column
    let targetColumn
    if (newStatus === 'pending') {
      targetColumn = this.hasPendingColumnTarget ? this.pendingColumnTarget : null
    } else if (newStatus === 'paid') {
      targetColumn = this.hasPaidColumnTarget ? this.paidColumnTarget : null
    } else if (newStatus === 'cancelled') {
      targetColumn = this.hasCancelledColumnTarget ? this.cancelledColumnTarget : null
    }
    
    if (targetColumn) {
      card.remove()
      targetColumn.appendChild(card)
      
      // Update column counts in headers
      this.updateColumnCounts()
    }
  }

  updateColumnCounts() {
    // Update counts in column headers
    if (this.hasPendingColumnTarget) {
      const pendingCount = this.pendingColumnTarget.children.length
      const pendingHeader = document.querySelector('.bg-yellow-100 .text-lg')
      if (pendingHeader) pendingHeader.textContent = pendingCount
    }
    
    if (this.hasPaidColumnTarget) {
      const paidCount = this.paidColumnTarget.children.length
      const paidHeader = document.querySelector('.bg-green-100 .text-lg')
      if (paidHeader) paidHeader.textContent = paidCount
    }
    
    if (this.hasCancelledColumnTarget) {
      const cancelledCount = this.cancelledColumnTarget.children.length
      const cancelledHeader = document.querySelector('.bg-gray-100 .text-lg')
      if (cancelledHeader) cancelledHeader.textContent = cancelledCount
    }
  }

  // ==================== UTILITY METHODS ====================

  getStatusText(status) {
    switch(status) {
      case 'paid': return 'Pago'
      case 'cancelled': return 'Cancelado'
      case 'pending': return 'Pendente'
      default: return status
    }
  }

  showToast(message, type) {
    const toast = document.createElement('div')
    toast.className = `fixed top-4 right-4 px-4 py-2 rounded-md text-white z-50 transition-opacity duration-300 ${
      type === 'success' ? 'bg-green-500' : 'bg-red-500'
    }`
    toast.textContent = message
    
    document.body.appendChild(toast)
    
    setTimeout(() => {
      toast.style.opacity = '0'
      setTimeout(() => toast.remove(), 300)
    }, 3000)
  }
}

