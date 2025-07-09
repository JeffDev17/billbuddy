import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["selectAll", "appointmentCheckbox", "selectedCount", "bulkSubmitBtn"]

  connect() {
    console.log("Daily completion controller connected")
    this.updateSelectedCount()
  }

  selectAllChanged() {
    const isChecked = this.selectAllTarget.checked
    this.appointmentCheckboxTargets.forEach(checkbox => {
      checkbox.checked = isChecked
    })
    this.updateSelectedCount()
  }

  appointmentCheckboxChanged() {
    this.updateSelectedCount()
    this.updateSelectAllState()
  }

  updateCompletionDates(event) {
    const completionDate = event.target.value
    const form = event.target.closest('form')
    const submitButton = form.querySelector('input[type="submit"]')
    
    if (completionDate) {
      submitButton.value = `Marcar Selecionadas como Concluídas (${completionDate})`
    } else {
      submitButton.value = "Marcar Selecionadas como Concluídas"
    }
  }

  updateSelectedCount() {
    const checkedBoxes = this.appointmentCheckboxTargets.filter(cb => cb.checked)
    this.selectedCountTarget.textContent = checkedBoxes.length
    this.bulkSubmitBtnTarget.disabled = checkedBoxes.length === 0
  }

  updateSelectAllState() {
    const appointmentCheckboxes = this.appointmentCheckboxTargets
    const allChecked = appointmentCheckboxes.every(cb => cb.checked)
    const someChecked = appointmentCheckboxes.some(cb => cb.checked)
    
    this.selectAllTarget.checked = allChecked
    this.selectAllTarget.indeterminate = someChecked && !allChecked
  }
} 