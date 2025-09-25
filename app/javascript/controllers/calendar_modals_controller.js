import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "modal", 
    "recurringOptions", 
    "form", 
    "eventSummary", 
    "eventLocation", 
    "eventDescription", 
    "eventDate", 
    "startTime", 
    "endTime", 
    "startTimeHidden", 
    "endTimeHidden"
  ]
  static values = { 
    currentEventId: String,
    type: { type: String, default: "combined" } // "delete", "edit", "combined"
  }

  connect() {
    this.initializeBasedOnType()
  }

  initializeBasedOnType() {
    switch (this.typeValue) {
      case "delete":
        this.initializeDeleteModal()
        break
      case "edit":
        this.initializeEditModal()
        break
      default:
        this.initializeCombinedModal()
    }
  }

  // Combined Modal functionality (handles both delete and edit)
  initializeCombinedModal() {
    this.populateEditTimeSelects()
    
    // Listen for successful form submissions
    if (this.hasFormTarget) {
      this.formTarget.addEventListener('ajax:success', (event) => {
        this.closeModal()
        this.refreshCalendarIframe()
      })

      this.formTarget.addEventListener('turbo:submit-end', (event) => {
        if (event.detail.success) {
          this.closeModal()
          this.refreshCalendarIframe()
        }
      })
    }
  }

  // Delete Modal functionality (was calendar_delete_controller.js)
  initializeDeleteModal() {
    // Delete modal specific initialization
  }

  deleteEvent(event) {
    this.currentEventIdValue = event.params.eventId
    const isRecurring = event.params.isRecurring
    
    // Convert string to boolean properly
    const isRecurringBool = isRecurring === 'true' || isRecurring === true
    
    if (this.hasRecurringOptionsTarget) {
      if (isRecurringBool) {
        this.recurringOptionsTarget.classList.remove('hidden')
      } else {
        this.recurringOptionsTarget.classList.add('hidden')
      }
    }
    
    if (this.hasModalTarget) {
      this.modalTarget.classList.remove('hidden')
    }
  }

  confirmDelete() {
    if (!this.currentEventIdValue) return
    
    const deleteType = document.querySelector('input[name="delete_type"]:checked')?.value || 'single'
    const form = document.createElement('form')
    form.method = 'POST'
    form.action = `/calendars/delete_event/${this.currentEventIdValue}`
    
    // Make the form submit remotely with Turbo Stream
    form.setAttribute('data-remote', 'true')
    form.setAttribute('data-turbo', 'true')
    
    // Add headers for Turbo Stream
    const turboHeader = document.createElement('input')
    turboHeader.type = 'hidden'
    turboHeader.name = 'HTTP_ACCEPT'
    turboHeader.value = 'text/vnd.turbo-stream.html'
    form.appendChild(turboHeader)
    
    // Add CSRF token
    const csrfToken = document.querySelector('meta[name="csrf-token"]').content
    const csrfInput = document.createElement('input')
    csrfInput.type = 'hidden'
    csrfInput.name = 'authenticity_token'
    csrfInput.value = csrfToken
    form.appendChild(csrfInput)
    
    // Add DELETE method
    const methodInput = document.createElement('input')
    methodInput.type = 'hidden'
    methodInput.name = '_method'
    methodInput.value = 'DELETE'
    form.appendChild(methodInput)
    
    // Add delete type for recurring events
    const deleteTypeInput = document.createElement('input')
    deleteTypeInput.type = 'hidden'
    deleteTypeInput.name = 'delete_type'
    deleteTypeInput.value = deleteType
    form.appendChild(deleteTypeInput)
    
    // Add the current date to maintain context
    const dateElement = document.querySelector('input[name="date"]')
    if (dateElement) {
      const dateInput = document.createElement('input')
      dateInput.type = 'hidden'
      dateInput.name = 'date'
      dateInput.value = dateElement.value
      form.appendChild(dateInput)
    }
    
    // Add success listener to close modal
    form.addEventListener('ajax:success', () => {
      this.closeModal()
      this.refreshCalendarIframe()
    })

    form.addEventListener('turbo:submit-end', (event) => {
      if (event.detail.success) {
        this.closeModal()
        this.refreshCalendarIframe()
      }
    })
    
    document.body.appendChild(form)
    
    // Submit using fetch to ensure proper headers
    const formData = new FormData(form)
    
    fetch(form.action, {
      method: 'DELETE',
      body: formData,
      headers: {
        'Accept': 'text/vnd.turbo-stream.html',
        'X-Requested-With': 'XMLHttpRequest'
      }
    }).then(response => {
      if (response.ok) {
        this.closeModal()
        this.refreshCalendarIframe()
        // Trigger page refresh or update
        window.location.reload()
      }
    }).catch(error => {
      console.error('Delete request failed:', error)
    })
  }

  // Edit Modal functionality (was calendar_edit_controller.js)
  initializeEditModal() {
    this.populateEditTimeSelects()
    
    // Listen for successful form submissions
    if (this.hasFormTarget) {
      this.formTarget.addEventListener('ajax:success', (event) => {
        this.closeModal()
        this.refreshCalendarIframe()
      })

      this.formTarget.addEventListener('turbo:submit-end', (event) => {
        if (event.detail.success) {
          this.closeModal()
          this.refreshCalendarIframe()
        }
      })
    }
  }

  editEvent(event) {
    const eventId = event.params.eventId
    
    // Update form action with event ID
    if (this.hasFormTarget) {
      this.formTarget.action = `/calendars/update_event/${eventId}`
      
      // Add date parameter if available
      const dateElement = document.querySelector('input[name="date"]')
      if (dateElement) {
        this.formTarget.action += `?date=${dateElement.value}`
      }
    }
    
    // Find the event in the event list
    const eventDiv = document.querySelector(`[data-event-id="${eventId}"]`)
    
    if (eventDiv && this.hasEventSummaryTarget) {
      // Fill the form with event data
      this.eventSummaryTarget.value = eventDiv.dataset.summary
      if (this.hasEventLocationTarget) {
        this.eventLocationTarget.value = eventDiv.dataset.location
      }
      if (this.hasEventDescriptionTarget) {
        this.eventDescriptionTarget.value = eventDiv.dataset.description
      }
      
      // Separate date and time from datetime
      const startDateTime = new Date(eventDiv.dataset.startTime)
      const endDateTime = new Date(eventDiv.dataset.endTime)
      
      // Format date for date field
      const dateStr = startDateTime.toISOString().split('T')[0]
      if (this.hasEventDateTarget) {
        this.eventDateTarget.value = dateStr
      }
      
      // Format times for selects (considering UTC-3)
      const startTimeStr = this.formatTimeForSelect(startDateTime)
      const endTimeStr = this.formatTimeForSelect(endDateTime)
      
      // Fill time selects
      this.populateEditTimeSelects()
      if (this.hasStartTimeTarget) {
        this.startTimeTarget.value = startTimeStr
      }
      if (this.hasEndTimeTarget) {
        this.endTimeTarget.value = endTimeStr
      }
      
      // Update hidden fields
      this.updateEditDateTime()
      
      // Show recurring event options if the event is recurring
      if (this.hasRecurringOptionsTarget) {
        if (eventDiv.dataset.recurringEventId) {
          this.recurringOptionsTarget.classList.remove('hidden')
        } else {
          this.recurringOptionsTarget.classList.add('hidden')
        }
      }
    }
    
    if (this.hasModalTarget) {
      this.modalTarget.classList.remove('hidden')
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

  // Populate time selects for editing
  populateEditTimeSelects() {
    const times = this.generateTimeOptions()
    
    if (this.hasStartTimeTarget) {
      this.startTimeTarget.innerHTML = ''
      times.forEach(time => {
        this.startTimeTarget.add(new Option(time, time))
      })
    }
    
    if (this.hasEndTimeTarget) {
      this.endTimeTarget.innerHTML = ''
      times.forEach(time => {
        this.endTimeTarget.add(new Option(time, time))
      })
    }
  }

  // Format time for select considering Brazil timezone
  formatTimeForSelect(date) {
    const hours = date.getHours().toString().padStart(2, '0')
    const minutes = date.getMinutes().toString().padStart(2, '0')
    return `${hours}:${minutes}`
  }

  // Update hidden datetime fields for editing
  updateEditDateTime() {
    if (this.hasEventDateTarget && this.hasStartTimeTarget && this.hasStartTimeHiddenTarget) {
      const date = this.eventDateTarget.value
      const startTime = this.startTimeTarget.value
      
      if (date && startTime) {
        this.startTimeHiddenTarget.value = `${date}T${startTime}`
      }
    }
    
    if (this.hasEventDateTarget && this.hasEndTimeTarget && this.hasEndTimeHiddenTarget) {
      const date = this.eventDateTarget.value
      const endTime = this.endTimeTarget.value
      
      if (date && endTime) {
        this.endTimeHiddenTarget.value = `${date}T${endTime}`
      }
    }
  }

  // Modal management
  closeModal() {
    if (this.hasModalTarget) {
      this.modalTarget.classList.add('hidden')
    }
    this.currentEventIdValue = ''
  }

  // Close modal when clicking outside
  closeOnOutsideClick(event) {
    if (this.hasModalTarget && event.target === this.modalTarget) {
      this.modalTarget.classList.add('hidden')
      this.currentEventIdValue = ''
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

  // Public methods for integration
  showDeleteModal(eventId, isRecurring = false) {
    this.currentEventIdValue = eventId
    
    if (this.hasRecurringOptionsTarget) {
      if (isRecurring) {
        this.recurringOptionsTarget.classList.remove('hidden')
      } else {
        this.recurringOptionsTarget.classList.add('hidden')
      }
    }
    
    if (this.hasModalTarget) {
      this.modalTarget.classList.remove('hidden')
    }
  }

  showEditModal(eventId) {
    this.editEvent({ params: { eventId: eventId } })
  }
}
