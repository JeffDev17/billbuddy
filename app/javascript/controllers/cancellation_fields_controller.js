import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="cancellation-fields"
export default class extends Controller {
  static targets = ["container"]

  connect() {
    this.toggleFields()
  }

  toggleFields() {
    const statusSelect = this.element.querySelector('select[name*="[status]"]')
    
    if (statusSelect.value === "cancelled") {
      this.containerTarget.classList.remove("hidden")
    } else {
      this.containerTarget.classList.add("hidden")
    }
  }
}
