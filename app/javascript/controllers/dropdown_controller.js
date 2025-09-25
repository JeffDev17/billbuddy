import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["menu"]
  
  connect() {
    // Close dropdown when clicking outside
    this.boundClickOutside = this.clickOutside.bind(this)
    document.addEventListener("click", this.boundClickOutside)
  }
  
  disconnect() {
    document.removeEventListener("click", this.boundClickOutside)
  }
  
  toggle(event) {
    event.stopPropagation()
    this.menuTarget.classList.toggle("hidden")
  }
  
  hide() {
    this.menuTarget.classList.add("hidden")
  }
  
  clickOutside(event) {
    if (!this.element.contains(event.target)) {
      this.hide()
    }
  }
} 