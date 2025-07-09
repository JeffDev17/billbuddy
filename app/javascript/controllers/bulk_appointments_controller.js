import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "selectAllCustomers", 
    "customerCheckbox", 
    "timeSlotsContainer", 
    "summary"
  ]
  static values = { defaultTimes: Array }

  connect() {
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
              data-action="click->bulk-appointments#removeTimeSlot"
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
              data-action="click->bulk-appointments#removeTimeSlot"
              class="px-2 py-2 text-red-600 dark:text-red-400 hover:text-red-800 dark:hover:text-red-200 focus:outline-none">
        ✕
      </button>
    `
    container.appendChild(timeSlotDiv)
  }

  updateSummary() {
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

    if (this.summaryTarget) {
      this.summaryTarget.innerHTML = summaryText
    }
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
} 