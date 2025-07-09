import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["form", "statusSelect", "customerSelect", "startDate", "endDate", "submitButton", "resultCount", "searchField", "sortSelect"]

  connect() {
    console.log("Appointment filters controller connected")
    this.setupAutoSubmit()
  }

  setupAutoSubmit() {
    // Auto-submit when select fields change
    if (this.hasStatusSelectTarget) {
      this.statusSelectTarget.addEventListener('change', () => {
        this.debouncedSubmit()
      })
    }

    if (this.hasCustomerSelectTarget) {
      this.customerSelectTarget.addEventListener('change', () => {
        this.debouncedSubmit()
      })
    }

    if (this.hasSortSelectTarget) {
      this.sortSelectTarget.addEventListener('change', () => {
        this.debouncedSubmit()
      })
    }

    // Auto-submit when date fields change (with slight delay)
    if (this.hasStartDateTarget) {
      this.startDateTarget.addEventListener('change', () => {
        this.debouncedSubmit()
      })
    }

    if (this.hasEndDateTarget) {
      this.endDateTarget.addEventListener('change', () => {
        this.debouncedSubmit()
      })
    }

    // Auto-submit when search field changes (with longer delay for typing)
    if (this.hasSearchFieldTarget) {
      this.searchFieldTarget.addEventListener('input', () => {
        this.debouncedSubmitSearch()
      })
    }
  }

  debouncedSubmit() {
    // Clear any existing timeout
    if (this.submitTimeout) {
      clearTimeout(this.submitTimeout)
    }

    // Set a new timeout
    this.submitTimeout = setTimeout(() => {
      this.submitForm()
    }, 500) // 500ms delay
  }

  debouncedSubmitSearch() {
    // Clear any existing timeout
    if (this.searchTimeout) {
      clearTimeout(this.searchTimeout)
    }

    // Set a longer timeout for search to allow for typing
    this.searchTimeout = setTimeout(() => {
      this.submitForm()
    }, 1000) // 1000ms delay for search
  }

  submitForm() {
    if (this.hasSubmitButtonTarget) {
      this.showLoading()
    }
    
    if (this.hasFormTarget) {
      this.formTarget.submit()
    }
  }

  showLoading() {
    const originalText = this.submitButtonTarget.textContent
    this.submitButtonTarget.textContent = "🔄 Carregando..."
    this.submitButtonTarget.disabled = true
    
    // Restore button after a brief moment (form submission will reload page anyway)
    setTimeout(() => {
      this.submitButtonTarget.textContent = originalText
      this.submitButtonTarget.disabled = false
    }, 2000)
  }

  clearFilters() {
    // Reset all form fields
    if (this.hasStatusSelectTarget) {
      this.statusSelectTarget.value = ''
    }
    
    if (this.hasCustomerSelectTarget) {
      this.customerSelectTarget.value = ''
    }
    
    if (this.hasStartDateTarget) {
      this.startDateTarget.value = ''
    }
    
    if (this.hasEndDateTarget) {
      this.endDateTarget.value = ''
    }

    if (this.hasSearchFieldTarget) {
      this.searchFieldTarget.value = ''
    }

    if (this.hasSortSelectTarget) {
      this.sortSelectTarget.value = 'earliest_first'
    }

    // Submit the form to apply changes
    this.submitForm()
  }

  disconnect() {
    // Clean up any pending timeouts
    if (this.submitTimeout) {
      clearTimeout(this.submitTimeout)
    }
    
    if (this.searchTimeout) {
      clearTimeout(this.searchTimeout)
    }
  }
} 