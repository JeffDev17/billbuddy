import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["content"]
  
  connect() {
    // Initialize with content hidden
    this.hideContent()
    
    // Listen for global toggle events
    document.addEventListener('sensitive-data:toggle-all', this.handleGlobalToggle.bind(this))
  }
  
  disconnect() {
    document.removeEventListener('sensitive-data:toggle-all', this.handleGlobalToggle.bind(this))
  }
  
  handleGlobalToggle(event) {
    if (event.detail.show) {
      this.showContent()
    } else {
      this.hideContent()
    }
  }
  
  hideContent() {
    this.contentTarget.classList.add('blur-sm', 'select-none')
    this.contentTarget.style.userSelect = 'none'
  }
  
  showContent() {
    this.contentTarget.classList.remove('blur-sm', 'select-none')
    this.contentTarget.style.userSelect = 'auto'
  }
} 