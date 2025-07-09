import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "statusSelect", 
    "paidCount", 
    "cancelledCount", 
    "pendingCount",
    "totalReceived",
    "totalCancelled", 
    "totalPending"
  ]

  connect() {
    console.log("Payment status controller connected")
  }

  async updateStatus(event) {
    const select = event.target
    const customerId = select.dataset.customerId
    const month = select.dataset.month
    const newStatus = select.value
    const oldStatus = select.dataset.currentStatus
    
    // If the status didn't change, do nothing
    if (newStatus === oldStatus) return
    
    // Disable the select temporarily
    select.disabled = true
    select.style.opacity = '0.6'
    
    try {
      const response = await fetch('/payments/update_payment_status', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
        },
        body: JSON.stringify({
          customer_id: customerId,
          month: month,
          status: newStatus
        })
      })
      
      const data = await response.json()
      
      if (data.success) {
        // Update the data attribute
        select.dataset.currentStatus = newStatus
        
        // Update counts immediately
        this.updateCounts(oldStatus, newStatus)
        
        // Update row visual styling based on new status
        this.updateRowStyling(customerId, newStatus)
        
        // Show success feedback
        this.showToast(`Status alterado para: ${this.getStatusText(newStatus)}`, 'success')
        
        // Optionally update totals via a lighter endpoint
        this.updateTotals()
        
        // Check if we need to reload for sorting (only if sorting by payment status)
        const currentSort = new URLSearchParams(window.location.search).get('sort_by')
        if (currentSort === 'payment_status' || currentSort === 'payment_status_reverse') {
          // Delay reload slightly to show the success toast first
          setTimeout(() => {
            window.location.reload()
          }, 1000)
        }
        
      } else {
        // Revert the selection if there's an error
        select.value = oldStatus
        this.showToast(data.message || 'Erro ao atualizar status', 'error')
      }
    } catch (error) {
      console.error('Error:', error)
      // Revert the selection if there's an error
      select.value = oldStatus
      this.showToast('Erro de conexão', 'error')
    } finally {
      // Re-enable the select
      select.disabled = false
      select.style.opacity = '1'
    }
  }

  updateCounts(oldStatus, newStatus) {
    // Update the visual counts without page reload
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
    // Optional: Fetch updated totals without reloading the page
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

  updateRowStyling(customerId, newStatus) {
    const customerRow = document.querySelector(`[data-customer-id="${customerId}"]`)
    if (!customerRow) return
    
    // Remove existing status classes
    customerRow.classList.remove(
      'bg-green-50', 'dark:bg-green-900/10', 'border-green-400',
      'bg-yellow-50', 'dark:bg-yellow-900/10', 'border-yellow-400', 
      'bg-red-50', 'dark:bg-red-900/10', 'border-red-400'
    )
    
    // Add new status classes
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
} 