import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["checkbox", "selectAll", "bulkActions", "markAllPaid", "markSelectedPaid", "selectedCount"]

  connect() {
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

    const month = this.data.get("month")
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

    const month = this.data.get("month")
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
    } catch (error) {
      alert('Erro ao processar pagamentos: ' + error.message)
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