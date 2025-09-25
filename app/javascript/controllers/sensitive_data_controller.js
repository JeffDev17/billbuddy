import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["content", "toggleIcon", "calendar"]
  static values = { 
    isVisible: { type: Boolean, default: true },
    namesVisible: { type: Boolean, default: true },
    eventsUrl: String,
    hideNames: { type: Boolean, default: false },
    type: { type: String, default: "general" } // "general", "global", "customerNames", "calendar"
  }

  connect() {
    this.initializeBasedOnType()
    this.setupEventListeners()
  }

  disconnect() {
    this.removeEventListeners()
  }

  initializeBasedOnType() {
    switch (this.typeValue) {
      case "global":
        this.initializeGlobalController()
        break
      case "customerNames":
        this.initializeCustomerNamesController()
        break
      case "calendar":
        this.initializeCalendarController()
        break
      default:
        this.initializeGeneralController()
    }
  }

  // Global Controller Functionality (was global_sensitive_data_controller.js)
  initializeGlobalController() {
    // Restore state from sessionStorage if available, default to visible
    const savedState = sessionStorage.getItem('sensitiveDataVisible')
    if (savedState !== null) {
      this.isVisibleValue = savedState === 'true'
    } else {
      this.isVisibleValue = true
    }
    
    this.updateGlobalIcon()
    
    // Immediately dispatch the current state to all sensitive data components
    this.dispatchToggleEvent('sensitive-data:toggle-all', { show: this.isVisibleValue })
  }

  toggleGlobal() {
    this.isVisibleValue = !this.isVisibleValue
    
    // Save state to sessionStorage
    sessionStorage.setItem('sensitiveDataVisible', this.isVisibleValue.toString())
    
    this.updateGlobalIcon()
    
    // Dispatch event to all sensitive data components
    this.dispatchToggleEvent('sensitive-data:toggle-all', { show: this.isVisibleValue })
  }

  updateGlobalIcon() {
    if (this.hasToggleIconTarget) {
      this.toggleIconTarget.textContent = this.isVisibleValue ? '👁️' : '👁️‍🗨️'
      const buttonText = this.toggleIconTarget.closest('button')?.querySelector('span:last-child')
      if (buttonText) {
        buttonText.textContent = this.isVisibleValue ? 'Ocultar Valores' : 'Mostrar Valores'
      }
    }
  }

  // Customer Names Controller Functionality (was customer_names_toggle_controller.js)
  initializeCustomerNamesController() {
    // Restore state from sessionStorage if available
    const savedState = sessionStorage.getItem('customerNamesVisible')
    if (savedState !== null) {
      this.namesVisibleValue = savedState === 'true'
    }
    this.updateCustomerNamesIcon()
  }

  toggleCustomerNames() {
    this.namesVisibleValue = !this.namesVisibleValue
    
    // Save state to sessionStorage
    sessionStorage.setItem('customerNamesVisible', this.namesVisibleValue.toString())
    
    this.updateCustomerNamesIcon()
    
    // Dispatch event to all sensitive data components
    this.dispatchToggleEvent('sensitive-data:toggle-all', { show: this.namesVisibleValue })
  }

  updateCustomerNamesIcon() {
    if (this.hasToggleIconTarget) {
      this.toggleIconTarget.textContent = this.namesVisibleValue ? '👁️' : '👁️‍🗨️'
      const buttonText = this.toggleIconTarget.closest('button')?.querySelector('span:last-child')
      if (buttonText) {
        buttonText.textContent = this.namesVisibleValue ? 'Ocultar Nomes' : 'Mostrar Nomes'
      }
    }
  }

  // Calendar Controller Functionality (was calendar_sensitive_data_controller.js)
  initializeCalendarController() {
    // Check if there's a customer names toggle controller on the page and sync with it
    this.syncWithToggleController()
  }

  // Method to be called by the fullcalendar controller
  setFullCalendar(calendar) {
    this.fullCalendar = calendar
    // After setting the calendar, check if we need to sync state
    this.syncWithToggleController()
  }
  
  syncWithToggleController() {
    // Find the customer names toggle controller
    const toggleElement = document.querySelector('[data-controller*="sensitive-data"][data-sensitive-data-type-value="customerNames"]')
    if (toggleElement) {
      const toggleController = this.application.getControllerForElementAndIdentifier(toggleElement, 'sensitive-data')
      if (toggleController) {
        // Sync our state with the toggle controller's state
        this.hideNamesValue = !toggleController.namesVisibleValue
        
        // If calendar is ready, refetch with correct state
        if (this.fullCalendar) {
          this.refetchEvents()
        }
      }
    }
  }

  refetchEvents() {
    if (!this.fullCalendar || !this.eventsUrlValue) return

    // Update the events URL with the hide_names parameter
    const url = new URL(this.eventsUrlValue, window.location.origin)
    url.searchParams.set('hide_names', this.hideNamesValue.toString())
    
    // Update the event source
    this.fullCalendar.removeAllEventSources()
    this.fullCalendar.addEventSource({
      url: url.toString(),
      method: 'GET',
      failure: (error) => {
        console.error('Failed to load events:', error)
      }
    })
  }

  // General Controller Functionality (was sensitive_data_controller.js)
  initializeGeneralController() {
    // Start with content visible by default - let global controller manage initial state
    this.showContent()
  }

  // Event Handlers
  setupEventListeners() {
    this.boundHandleGlobalToggle = this.handleGlobalToggle.bind(this)
    document.addEventListener('sensitive-data:toggle-all', this.boundHandleGlobalToggle)
  }

  removeEventListeners() {
    if (this.boundHandleGlobalToggle) {
      document.removeEventListener('sensitive-data:toggle-all', this.boundHandleGlobalToggle)
    }
  }

  handleGlobalToggle(event) {
    switch (this.typeValue) {
      case "calendar":
        this.handleCalendarGlobalToggle(event)
        break
      case "customerNames":
        // Customer names controller handles its own events
        break
      case "global":
        // Global controller dispatches events, doesn't listen to them
        break
      default:
        this.handleGeneralGlobalToggle(event)
    }
  }

  handleCalendarGlobalToggle(event) {
    // Update the hide names state
    this.hideNamesValue = !event.detail.show
    
    // If there's a FullCalendar instance, refetch events
    if (this.fullCalendar) {
      this.refetchEvents()
    }
  }

  handleGeneralGlobalToggle(event) {
    if (event.detail.show) {
      this.showContent()
    } else {
      this.hideContent()
    }
  }

  // Content manipulation methods
  hideContent() {
    if (this.hasContentTarget) {
      this.contentTarget.classList.add('blur-sm', 'select-none')
      this.contentTarget.style.userSelect = 'none'
    }
  }

  showContent() {
    if (this.hasContentTarget) {
      this.contentTarget.classList.remove('blur-sm', 'select-none')
      this.contentTarget.style.userSelect = 'auto'
    }
  }

  // Utility methods
  dispatchToggleEvent(eventName, detail) {
    document.dispatchEvent(new CustomEvent(eventName, { detail }))
  }

  // Public API methods for backwards compatibility
  toggle() {
    switch (this.typeValue) {
      case "global":
        this.toggleGlobal()
        break
      case "customerNames":
        this.toggleCustomerNames()
        break
      default:
        // For general controllers, just toggle content visibility
        if (this.hasContentTarget) {
          const isCurrentlyVisible = !this.contentTarget.classList.contains('blur-sm')
          if (isCurrentlyVisible) {
            this.hideContent()
          } else {
            this.showContent()
          }
        }
    }
  }
}