import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["recurringCheckbox", "recurringOptions", "noEndDateCheckbox", "endDateField"]

  connect() {
    console.log("Appointment recurring controller connected")
  }

  toggleRecurring(event) {
    if (event.target.checked) {
      this.recurringOptionsTarget.classList.remove("hidden")
    } else {
      this.recurringOptionsTarget.classList.add("hidden")
      // Clear all checkboxes when hiding
      this.clearRecurringOptions()
    }
  }

  toggleEndDate(event) {
    if (event.target.checked) {
      // Disable the date field when "indefinite" is checked
      this.endDateFieldTarget.disabled = true
      this.endDateFieldTarget.value = ""
      this.endDateFieldTarget.classList.add("opacity-50")
    } else {
      // Enable the date field
      this.endDateFieldTarget.disabled = false
      this.endDateFieldTarget.classList.remove("opacity-50")
    }
  }

  clearRecurringOptions() {
    // Clear all day checkboxes
    const dayCheckboxes = this.element.querySelectorAll('input[name="recurring_days[]"]')
    dayCheckboxes.forEach(checkbox => {
      checkbox.checked = false
    })
    
    // Clear end date options
    this.noEndDateCheckboxTarget.checked = false
    this.endDateFieldTarget.value = ""
    this.endDateFieldTarget.disabled = false
    this.endDateFieldTarget.classList.remove("opacity-50")
  }
} 