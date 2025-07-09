import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["customerSelect", "deleteButton", "futureOnlyCheckbox"]

  connect() {
    console.log("Bulk delete controller connected")
    this.updateDeleteButton()
  }

  customerSelectTargetConnected() {
    this.customerSelectTarget.addEventListener('change', () => {
      this.updateDeleteButton()
    })
  }

  updateDeleteButton() {
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
} 