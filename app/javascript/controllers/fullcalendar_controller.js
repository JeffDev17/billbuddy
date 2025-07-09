import { Controller } from "@hotwired/stimulus"
import { Calendar } from "@fullcalendar/core"
import dayGridPlugin from "@fullcalendar/daygrid"
import timeGridPlugin from "@fullcalendar/timegrid"
import interactionPlugin from "@fullcalendar/interaction"
import listPlugin from "@fullcalendar/list"

export default class extends Controller {
  static targets = ["calendar"]
  static values = { 
    eventsUrl: String,
    selectedDate: String,
    locale: { type: String, default: "pt-br" }
  }

  connect() {
    this.initializeCalendar()
  }

  disconnect() {
    if (this.calendar) {
      this.calendar.destroy()
    }
  }

  initializeCalendar() {
    // Create calendar instance
    this.calendar = new Calendar(this.calendarTarget, {
      plugins: [dayGridPlugin, timeGridPlugin, interactionPlugin, listPlugin],
      
      // Calendar configuration
      locale: this.localeValue,
      timeZone: 'local', // Use browser's local timezone (should be Brazil)
      initialDate: new Date(), // Use browser's current date
      firstDay: 0, // Sunday
      height: 'auto',
      
      // Default view
      initialView: window.innerWidth < 768 ? 'listWeek' : 'timeGridWeek',
      
      // View options
      headerToolbar: {
        left: 'prev,next today',
        center: 'title',
        right: 'dayGridMonth,timeGridWeek,timeGridDay,listWeek'
      },
      
      // Time settings
      slotMinTime: '06:00:00',
      slotMaxTime: '22:00:00',
      slotDuration: '00:30:00',
      allDaySlot: false,
      
      // Event settings
      eventDisplay: 'block',
      displayEventTime: true,
      displayEventEnd: false,
      eventTimeFormat: {
        hour: '2-digit',
        minute: '2-digit',
        hour12: false
      },
      
      // Business hours (optional - you can customize)
      businessHours: {
        daysOfWeek: [1, 2, 3, 4, 5, 6], // Monday - Saturday
        startTime: '08:00',
        endTime: '18:00'
      },
      
      // Event sources
      events: {
        url: this.eventsUrlValue,
        method: 'GET',
        failure: (error) => {
          console.error('Failed to load events:', error)
          this.showError('Erro ao carregar compromissos')
        }
      },
      
      // Event interactions
      selectable: true,
      selectMirror: true,
      editable: true,
      
      // Event callbacks
      select: this.handleDateSelect.bind(this),
      eventClick: this.handleEventClick.bind(this),
      eventDrop: this.handleEventDrop.bind(this),
      eventResize: this.handleEventResize.bind(this),
      
      // Loading indicator
      loading: (isLoading) => {
        this.toggleLoadingState(isLoading)
      }
    })

    // Set initial date if provided
    if (this.selectedDateValue) {
      this.calendar.gotoDate(this.selectedDateValue)
    }

    // Render calendar
    this.calendar.render()
    
    // Apply dark theme styles after render
    this.applyDarkTheme()
  }

  applyDarkTheme() {
    // Check if we're in dark mode - only fix header text readability
    if (document.documentElement.classList.contains('dark')) {
      // Inject minimal styles to fix header text readability
      const style = document.createElement('style')
      style.textContent = `
        /* Fix header text readability in dark mode */
        .fc-col-header-cell {
          color: #111827 !important;
          font-weight: 600 !important;
        }
        
        .fc-daygrid-day-number {
          color: #374151 !important;
        }
        
        .fc-toolbar-title {
          color: #f9fafb !important;
        }
        
        .fc-timegrid-slot-label {
          color: #6b7280 !important;
        }
      `
      
      // Append to calendar container
      this.calendarTarget.appendChild(style)
    }
  }

  // Handle date selection for creating new appointments
  handleDateSelect(selectInfo) {
    const start = selectInfo.start
    const end = selectInfo.end
    
    // Clear the selection
    this.calendar.unselect()
    
    // Create new appointment with selected time
    this.createAppointment(start, end)
  }

  // Handle clicking on existing events
  handleEventClick(clickInfo) {
    const event = clickInfo.event
    const appointmentId = event.id
    
    // Show appointment details/edit modal
    this.showAppointmentDetails(appointmentId, event)
  }

  // Handle dragging events to new times
  handleEventDrop(dropInfo) {
    const event = dropInfo.event
    const appointmentId = event.id
    const newStart = event.start
    const newEnd = event.end
    
    // Update appointment time via AJAX
    this.updateAppointmentTime(appointmentId, newStart, newEnd)
      .catch(() => {
        // Revert the change if update fails
        dropInfo.revert()
        this.showError('Erro ao atualizar horário do compromisso')
      })
  }

  // Handle resizing events
  handleEventResize(resizeInfo) {
    const event = resizeInfo.event
    const appointmentId = event.id
    const newStart = event.start
    const newEnd = event.end
    
    // Update appointment duration via AJAX
    this.updateAppointmentTime(appointmentId, newStart, newEnd)
      .catch(() => {
        // Revert the change if update fails
        resizeInfo.revert()
        this.showError('Erro ao atualizar duração do compromisso')
      })
  }

  // API methods
  async createAppointment(start, end) {
    const url = '/appointments/new'
    
    // Format date as local datetime string (without timezone info)
    const formatAsLocal = (date) => {
      const year = date.getFullYear()
      const month = String(date.getMonth() + 1).padStart(2, '0')
      const day = String(date.getDate()).padStart(2, '0')
      const hours = String(date.getHours()).padStart(2, '0')
      const minutes = String(date.getMinutes()).padStart(2, '0')
      const seconds = String(date.getSeconds()).padStart(2, '0')
      
      return `${year}-${month}-${day}T${hours}:${minutes}:${seconds}`
    }
    
    const params = new URLSearchParams({
      scheduled_at: formatAsLocal(start),
      duration: Math.round((end - start) / (1000 * 60 * 60)) // hours
    })
    
    // Navigate to new appointment form with pre-filled time
    window.location.href = `${url}?${params}`
  }

  async showAppointmentDetails(appointmentId, event) {
    // Navigate to appointment edit page
    window.location.href = `/appointments/${appointmentId}/edit`
  }

  async updateAppointmentTime(appointmentId, newStart, newEnd) {
    const duration = Math.round((newEnd - newStart) / (1000 * 60 * 60))
    
    const formatAsLocal = (date) => {
      const year = date.getFullYear()
      const month = String(date.getMonth() + 1).padStart(2, '0')
      const day = String(date.getDate()).padStart(2, '0')
      const hours = String(date.getHours()).padStart(2, '0')
      const minutes = String(date.getMinutes()).padStart(2, '0')
      const seconds = String(date.getSeconds()).padStart(2, '0')
      
      return `${year}-${month}-${day}T${hours}:${minutes}:${seconds}`
    }
    
    const response = await fetch(`/appointments/${appointmentId}`, {
      method: 'PATCH',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': this.getCSRFToken(),
        'Accept': 'application/json'
      },
      body: JSON.stringify({
        appointment: {
          scheduled_at: formatAsLocal(newStart),
          duration: duration
        }
      })
    })

    if (!response.ok) {
      throw new Error('Failed to update appointment')
    }

    // Show success message
    this.showSuccess('Compromisso atualizado com sucesso!')
    
    return response.json()
  }

  // Utility methods
  getCSRFToken() {
    const token = document.querySelector('meta[name="csrf-token"]')
    return token ? token.getAttribute('content') : ''
  }

  toggleLoadingState(isLoading) {
    const loadingIndicator = this.element.querySelector('.calendar-loading')
    if (loadingIndicator) {
      loadingIndicator.style.display = isLoading ? 'flex' : 'none'
    }
  }

  showError(message) {
    this.showFlashMessage(message, 'error')
  }

  showSuccess(message) {
    this.showFlashMessage(message, 'success')
  }

  showFlashMessage(message, type) {
    // Create flash message element
    const flashContainer = document.getElementById('flash-messages')
    if (!flashContainer) return

    const messageDiv = document.createElement('div')
    messageDiv.className = `flash-message rounded-lg px-4 py-3 shadow-lg ${
      type === 'error' 
        ? 'bg-red-100 border border-red-400 text-red-700' 
        : 'bg-green-100 border border-green-400 text-green-700'
    }`
    messageDiv.textContent = message

    flashContainer.appendChild(messageDiv)

    // Auto-remove after 5 seconds
    setTimeout(() => {
      messageDiv.remove()
    }, 5000)
  }

  // Public methods for external calendar updates
  refreshEvents() {
    if (this.calendar) {
      this.calendar.refetchEvents()
    }
  }

  goToDate(date) {
    if (this.calendar) {
      this.calendar.gotoDate(date)
    }
  }

  addEvent(eventData) {
    if (this.calendar) {
      this.calendar.addEvent(eventData)
    }
  }

  removeEvent(eventId) {
    if (this.calendar) {
      const event = this.calendar.getEventById(eventId)
      if (event) {
        event.remove()
      }
    }
  }

  updateEvent(eventId, updates) {
    if (this.calendar) {
      const event = this.calendar.getEventById(eventId)
      if (event) {
        for (const [key, value] of Object.entries(updates)) {
          event.setProp(key, value)
        }
      }
    }
  }
} 