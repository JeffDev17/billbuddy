import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["toggleIcon"]
  static values = {
    isVisible: { type: Boolean, default: false }
  }
  
  connect() {
    this.updateIcon()
  }
  
  toggle() {
    this.isVisibleValue = !this.isVisibleValue
    this.updateIcon()
    
    // Dispatch event to all sensitive data components
    document.dispatchEvent(new CustomEvent('sensitive-data:toggle-all', {
      detail: { show: this.isVisibleValue }
    }))
  }
  
  updateIcon() {
    this.toggleIconTarget.textContent = this.isVisibleValue ? '👁️' : '👁️‍🗨️'
    const buttonText = this.toggleIconTarget.closest('button').querySelector('span:last-child')
    buttonText.textContent = this.isVisibleValue ? 'Ocultar Valores' : 'Mostrar Valores'
  }
} 