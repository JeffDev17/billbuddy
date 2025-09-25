import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["form"]
  static values = { 
    selectedDate: String,
    type: { type: String, default: "main" } // "main", "page", "toggle", "dateSelector"
  }

  connect() {
    this.initializeBasedOnType()
  }

  initializeBasedOnType() {
    switch (this.typeValue) {
      case "page":
        this.initializePage()
        break
      case "toggle":
        this.initializeToggle()
        break
      case "dateSelector":
        this.initializeDateSelector()
        break
      default:
        this.initializeMain()
    }
  }

  // Main Calendar Controller (consolidates calendar_actions_controller.js)
  initializeMain() {
    // Main calendar initialization
    console.log("Main calendar controller initialized")
  }

  editEvent(event) {
    const eventId = event.params.eventId
    
    // Dispatch to the modal controller
    const modalController = this.getModalController()
    if (modalController) {
      modalController.editEvent(event)
    }
  }

  deleteEvent(event) {
    const eventId = event.params.eventId
    const isRecurring = event.params.isRecurring
    
    // Dispatch to the modal controller
    const modalController = this.getModalController()
    if (modalController) {
      modalController.deleteEvent(event)
    }
  }

  getModalController() {
    const modalElement = document.querySelector('[data-controller*="calendar-modals"]')
    if (modalElement) {
      return this.application.getControllerForElementAndIdentifier(modalElement, 'calendar-modals')
    }
    return null
  }

  // Page Controller functionality (was calendar_page_controller.js)
  initializePage() {
    this.updateCalendarIframe()
  }

  selectedDateValueChanged() {
    if (this.typeValue === "page") {
      this.updateCalendarIframe()
    }
  }

  // Update the Google Calendar iframe to show the selected date
  updateCalendarIframe() {
    const iframe = document.getElementById('google-calendar-iframe')
    if (iframe && this.selectedDateValue) {
      // Parse the date to get the week
      const selectedDate = new Date(this.selectedDateValue)
      const year = selectedDate.getFullYear()
      const month = String(selectedDate.getMonth() + 1).padStart(2, '0')
      const day = String(selectedDate.getDate()).padStart(2, '0')
      
      // Update the iframe src to show the selected week
      const currentSrc = iframe.src
      // Remove any existing date parameters
      let baseUrl = currentSrc.split('&dates=')[0]
      if (baseUrl.includes('&_refresh=')) {
        baseUrl = baseUrl.split('&_refresh=')[0]
      }
      
      // Add the date parameter to center the calendar on that week
      const newSrc = `${baseUrl}&dates=${year}${month}${day}%2F${year}${month}${day}&_refresh=${new Date().getTime()}`
      
      if (currentSrc !== newSrc) {
        iframe.src = newSrc
      }
    }
  }

  // Refresh the Google Calendar iframe to show updated events
  refreshCalendarIframe() {
    const iframe = document.getElementById('google-calendar-iframe')
    if (iframe) {
      // Force refresh by updating the src with a timestamp
      const currentSrc = iframe.src
      const separator = currentSrc.includes('?') ? '&' : '?'
      iframe.src = currentSrc.split('&_refresh')[0] + separator + '_refresh=' + new Date().getTime()
    }
  }

  // Toggle Controller functionality (was calendar_toggle_controller.js)
  initializeToggle() {
    // Simple toggle initialization
  }

  toggle() {
    if (this.hasFormTarget) {
      this.formTarget.classList.toggle('hidden')
    }
  }

  hide() {
    if (this.hasFormTarget) {
      this.formTarget.classList.add('hidden')
    }
  }

  show() {
    if (this.hasFormTarget) {
      this.formTarget.classList.remove('hidden')
    }
  }

  // Date Selector functionality (was date_selector_controller.js)
  initializeDateSelector() {
    // Date selector initialization
  }

  navigate() {
    const selectedDate = this.element.value
    if (selectedDate) {
      // Navigate to the selected date using Turbo
      window.Turbo.visit(`/calendars?date=${selectedDate}`)
    }
  }

  // Form Controller functionality (was calendar_form_controller.js)
  initializeFormController() {
    this.populateTimeSelects()
    this.setMinDate()
    
    // Add form submission listeners
    if (this.hasFormTarget) {
      this.formTarget.addEventListener('ajax:success', (event) => {
        this.resetForm()
        this.hideForm()
        this.refreshCalendarIframe()
      })

      this.formTarget.addEventListener('turbo:submit-end', (event) => {
        if (event.detail.success) {
          this.resetForm()
          this.hideForm()
          this.refreshCalendarIframe()
        }
      })

      // Watch for new flash messages (indicates successful submission) - backup method
      const flashContainer = document.getElementById('flash-messages')
      if (flashContainer) {
        const observer = new MutationObserver((mutations) => {
          mutations.forEach((mutation) => {
            if (mutation.type === 'childList' && mutation.addedNodes.length > 0) {
              // Check if a flash message was added
              const addedNode = mutation.addedNodes[0]
              if (addedNode.nodeType === Node.ELEMENT_NODE && 
                  (addedNode.classList?.contains('bg-green-100') || addedNode.querySelector('.bg-green-100'))) {
                this.refreshCalendarIframe()
              }
            }
          })
        })
        observer.observe(flashContainer, { childList: true, subtree: true })
      }
    }
  }

  // Generate time options in 15-minute intervals
  generateTimeOptions() {
    const times = []
    for (let hour = 0; hour < 24; hour++) {
      for (let minute = 0; minute < 60; minute += 15) {
        const hourStr = hour.toString().padStart(2, '0')
        const minuteStr = minute.toString().padStart(2, '0')
        times.push(`${hourStr}:${minuteStr}`)
      }
    }
    return times
  }

  // Populate time selects
  populateTimeSelects() {
    const times = this.generateTimeOptions()
    
    const startTimeSelect = this.element.querySelector('[data-calendar-target="startTime"]')
    const endTimeSelect = this.element.querySelector('[data-calendar-target="endTime"]')
    
    if (startTimeSelect) {
      startTimeSelect.innerHTML = ''
      times.forEach(time => {
        startTimeSelect.add(new Option(time, time))
      })
    }
    
    if (endTimeSelect) {
      endTimeSelect.innerHTML = ''
      times.forEach(time => {
        endTimeSelect.add(new Option(time, time))
      })
    }
  }

  // Set minimum date as today
  setMinDate() {
    const dateInput = this.element.querySelector('[data-calendar-target="eventDate"]')
    if (dateInput) {
      const today = new Date().toISOString().split('T')[0]
      dateInput.min = today
    }
  }

  // Update date/time hidden fields
  updateDateTime() {
    const dateInput = this.element.querySelector('[data-calendar-target="eventDate"]')
    const startTimeSelect = this.element.querySelector('[data-calendar-target="startTime"]')
    const endTimeSelect = this.element.querySelector('[data-calendar-target="endTime"]')
    const startTimeHidden = this.element.querySelector('[data-calendar-target="startTimeHidden"]')
    const endTimeHidden = this.element.querySelector('[data-calendar-target="endTimeHidden"]')
    
    if (dateInput && startTimeSelect && startTimeHidden) {
      const date = dateInput.value
      const startTime = startTimeSelect.value
      
      if (date && startTime) {
        startTimeHidden.value = `${date}T${startTime}`
      }
    }
    
    if (dateInput && endTimeSelect && endTimeHidden) {
      const date = dateInput.value
      const endTime = endTimeSelect.value
      
      if (date && endTime) {
        endTimeHidden.value = `${date}T${endTime}`
      }
    }
  }

  // Toggle recurring options
  toggleRecurring() {
    const recurringOptions = this.element.querySelector('[data-calendar-target="recurringOptions"]')
    if (recurringOptions) {
      recurringOptions.classList.toggle('hidden')
    }
  }

  // Function to toggle end date field (for compatibility with existing onclick)
  toggleEndDateField() {
    const noEndDateCheckbox = document.getElementById('no_end_date')
    const recurringUntilField = document.getElementById('recurring_until')
    
    if (noEndDateCheckbox && recurringUntilField) {
      if (noEndDateCheckbox.checked) {
        recurringUntilField.disabled = true
        recurringUntilField.value = ''
      } else {
        recurringUntilField.disabled = false
      }
    }
  }

  resetForm() {
    if (this.hasFormTarget) {
      this.formTarget.reset()
      this.populateTimeSelects() // Repopulate selects after reset
      
      const recurringOptions = this.element.querySelector('[data-calendar-target="recurringOptions"]')
      if (recurringOptions) {
        recurringOptions.classList.add('hidden')
      }
    }
  }

  hideForm() {
    // Find the toggle target directly and hide it
    const formContainer = this.element.closest('[data-calendar-toggle-target="form"]')
    if (formContainer) {
      formContainer.classList.add('hidden')
    } else if (this.hasFormTarget) {
      this.formTarget.classList.add('hidden')
    }
  }

  // Public methods for external use
  goToDate(date) {
    this.selectedDateValue = date
  }

  refreshIframe() {
    this.refreshCalendarIframe()
  }
}
