import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["completionForm"]

  connect() {
    // Bind the click outside handler
    this.clickOutsideHandler = this.closeAllForms.bind(this)
    document.addEventListener('click', this.clickOutsideHandler)
  }

  disconnect() {
    // Clean up event listener
    document.removeEventListener('click', this.clickOutsideHandler)
  }

  // Toggle completion form with smart positioning
  toggleCompletionForm(event) {
    const appointmentId = event.params.appointmentId
    const form = document.getElementById(`completion-form-${appointmentId}`)
    const button = event.target.closest('button')
    
    // Close other forms first
    document.querySelectorAll('[id^="completion-form-"]').forEach(otherForm => {
      if (otherForm.id !== `completion-form-${appointmentId}`) {
        otherForm.classList.add('hidden')
      }
    })
    
    // Toggle current form
    form.classList.toggle('hidden')
    
    if (!form.classList.contains('hidden')) {
      // Position the form using fixed coordinates
      const buttonRect = button.getBoundingClientRect()
      const formWidth = 220 // approximate width of the form
      
      // Position to the left of the button, but ensure it stays on screen
      let leftPosition = buttonRect.left - formWidth
      if (leftPosition < 10) {
        leftPosition = 10 // minimum margin from left edge
      }
      
      // Position below the button
      const topPosition = buttonRect.bottom + 5
      
      form.style.left = leftPosition + 'px'
      form.style.top = topPosition + 'px'
    }
  }

  // Close completion forms when clicking outside
  closeAllForms(event) {
    const completionForms = document.querySelectorAll('[id^="completion-form-"]')
    completionForms.forEach(form => {
      if (!form.contains(event.target) && !event.target.closest('button[data-action*="toggleCompletionForm"]')) {
        form.classList.add('hidden')
      }
    })
  }

  // Close specific form
  closeForm(event) {
    const formId = event.params.formId
    const form = document.getElementById(formId)
    if (form) {
      form.classList.add('hidden')
    }
  }
} 