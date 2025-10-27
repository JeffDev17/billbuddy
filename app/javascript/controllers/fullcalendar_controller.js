import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["calendar"]
  static values = { 
    eventsUrl: String,
    selectedDate: String,
    locale: { type: String, default: "pt-br" }
  }

  connect() {
    if (!window.FullCalendar) {
      console.error("❌ FullCalendar not loaded from CDN")
      return
    }
    
    this.initializeCalendar()

    // Connect with sensitive-data controller
    setTimeout(() => {
      const sensitiveDataController = this.application.getControllerForElementAndIdentifier(
        this.element, 
        'sensitive-data'
      )
      if (sensitiveDataController) {
        sensitiveDataController.setFullCalendar(this.calendar)
      }
    }, 100)

    // Simple calendar refresh - no complex event handling needed
  }

  disconnect() {
    if (this.calendar) {
      this.calendar.destroy()
    }
  }

  initializeCalendar() {
    // Check if FullCalendar is available
    if (!window.FullCalendar) {
      console.error("FullCalendar not loaded. Make sure the CDN is accessible.")
      return
    }

    const { Calendar } = window.FullCalendar

    // Create calendar instance
    this.calendar = new Calendar(this.calendarTarget, {
      // Calendar configuration
      locale: this.localeValue,
      timeZone: 'local',
      initialDate: new Date(),
      firstDay: 0,
      height: 'auto',
      
      // Default view - always start with week view for better performance
      initialView: 'timeGridWeek',
      
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
      
      // Business hours
      businessHours: {
        daysOfWeek: [1, 2, 3, 4, 5, 6],
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
    
    // Store global reference for external access
    window.fullCalendarInstance = this.calendar
    console.log('FullCalendar initialized and ready, instance stored globally')
    
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
    // Create action modal instead of directly navigating
    this.showAppointmentActionModal(appointmentId, event)
  }

  showAppointmentActionModal(appointmentId, event) {
    const extendedProps = event.extendedProps
    const customerName = extendedProps.customerName
    const status = extendedProps.status
    const startTime = event.start.toLocaleString('pt-BR')
    const duration = extendedProps.duration
    
    // Create modal HTML
    const modalHtml = `
      <div id="appointment-action-modal" class="fixed inset-0 z-50 overflow-y-auto" aria-labelledby="modal-title" role="dialog" aria-modal="true">
        <div class="flex items-center justify-center min-h-screen px-4 text-center sm:block sm:p-0">
          <div class="fixed inset-0 transition-opacity bg-gray-500 bg-opacity-75" aria-hidden="true"></div>
          
          <div class="inline-block overflow-hidden text-left align-bottom transition-all transform bg-white rounded-lg shadow-xl sm:my-8 sm:align-middle sm:max-w-lg sm:w-full">
            <div class="bg-white px-4 pt-5 pb-4 sm:p-6 sm:pb-4">
              <div class="sm:flex sm:items-start">
                <div class="w-full">
                  <h3 class="text-lg font-medium leading-6 text-gray-900 mb-4" id="modal-title">
                    ${customerName}
                  </h3>
                  
                  <div class="mb-4 p-3 bg-blue-50 rounded-lg">
                    <p class="text-sm text-blue-800">
                      <strong>Data/Hora:</strong> ${startTime}<br>
                      <strong>Duração:</strong> ${duration}h<br>
                      <strong>Status:</strong> ${status}
                    </p>
                  </div>

                  <div class="flex flex-col space-y-3">
                    ${status === 'scheduled' ? `
                      <button onclick="document.getElementById('appointment-action-modal').remove(); window.location.href='/appointments/${appointmentId}/edit'" 
                              class="w-full bg-blue-600 hover:bg-blue-700 text-white px-4 py-2 rounded-md transition-colors">
                        ✏️ Editar Compromisso
                      </button>
                      
                      <button onclick="document.getElementById('appointment-action-modal').remove(); openCancellationModal(${appointmentId})" 
                              class="w-full bg-red-600 hover:bg-red-700 text-white px-4 py-2 rounded-md transition-colors">
                        ❌ Cancelar Compromisso
                      </button>
                      
                      <form action="/appointments/${appointmentId}/mark_completed" method="post" style="width: 100%;"
                            onsubmit="if(confirm('Marcar como concluída?')) { document.getElementById('appointment-action-modal').remove(); return true; } else { return false; }">
                        <input type="hidden" name="_method" value="post">
                        <input type="hidden" name="authenticity_token" value="${document.querySelector('meta[name="csrf-token"]').content}">
                        <input type="hidden" name="completion_date" value="${event.start.toISOString().split('T')[0]}">
                        <button type="submit" 
                                class="w-full bg-green-600 hover:bg-green-700 text-white px-4 py-2 rounded-md transition-colors">
                          ✓ Marcar como Concluída
                        </button>
                      </form>
                      
                      <form action="/appointments/${appointmentId}" method="post" style="width: 100%;"
                            onsubmit="if(confirm('⚠️ Tem certeza que deseja EXCLUIR este compromisso?\\n\\nEsta ação não pode ser desfeita!')) { document.getElementById('appointment-action-modal').remove(); return true; } else { return false; }">
                        <input type="hidden" name="_method" value="delete">
                        <input type="hidden" name="authenticity_token" value="${document.querySelector('meta[name="csrf-token"]').content}">
                        <button type="submit" 
                                class="w-full bg-gray-800 hover:bg-black text-white px-4 py-2 rounded-md transition-colors border border-gray-600">
                          🗑️ Excluir Compromisso
                        </button>
                      </form>
                    ` : status === 'cancelled' && extendedProps.canReschedule ? `
                      <span class="text-sm text-orange-600 mb-2">Este compromisso pode ser reagendado</span>
                      <button onclick="document.getElementById('appointment-action-modal').remove(); window.location.href='/appointments/${appointmentId}/edit'" 
                              class="w-full bg-orange-600 hover:bg-orange-700 text-white px-4 py-2 rounded-md transition-colors">
                        📅 Reagendar Compromisso
                      </button>
                      
                      <form action="/appointments/${appointmentId}" method="post" style="width: 100%;"
                            onsubmit="if(confirm('⚠️ Tem certeza que deseja EXCLUIR este compromisso?\\n\\nEsta ação não pode ser desfeita!')) { document.getElementById('appointment-action-modal').remove(); return true; } else { return false; }">
                        <input type="hidden" name="_method" value="delete">
                        <input type="hidden" name="authenticity_token" value="${document.querySelector('meta[name="csrf-token"]').content}">
                        <button type="submit" 
                                class="w-full bg-gray-800 hover:bg-black text-white px-4 py-2 rounded-md transition-colors border border-gray-600">
                          🗑️ Excluir Compromisso
                        </button>
                      </form>
                    ` : `
                      <button onclick="document.getElementById('appointment-action-modal').remove(); window.location.href='/appointments/${appointmentId}/edit'" 
                              class="w-full bg-gray-600 hover:bg-gray-700 text-white px-4 py-2 rounded-md transition-colors">
                        👁️ Ver Detalhes
                      </button>
                      
                      <form action="/appointments/${appointmentId}" method="post" style="width: 100%;"
                            onsubmit="if(confirm('⚠️ Tem certeza que deseja EXCLUIR este compromisso?\\n\\nEsta ação não pode ser desfeita!')) { document.getElementById('appointment-action-modal').remove(); return true; } else { return false; }">
                        <input type="hidden" name="_method" value="delete">
                        <input type="hidden" name="authenticity_token" value="${document.querySelector('meta[name="csrf-token"]').content}">
                        <button type="submit" 
                                class="w-full bg-gray-800 hover:bg-black text-white px-4 py-2 rounded-md transition-colors border border-gray-600">
                          🗑️ Excluir Compromisso
                        </button>
                      </form>
                    `}
                  </div>
                  
                  <div class="flex justify-end mt-4 pt-4 border-t">
                    <button type="button" 
                            onclick="document.getElementById('appointment-action-modal').remove()" 
                            class="px-4 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-md hover:bg-gray-50">
                      Fechar
                    </button>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    `
    
    // Add modal to page
    document.body.insertAdjacentHTML('beforeend', modalHtml)
    
    // Close modal when clicking outside
    document.getElementById('appointment-action-modal').addEventListener('click', function(e) {
      if (e.target === this) {
        this.remove()
      }
    })
  }

  async updateAppointmentTime(appointmentId, newStart, newEnd) {
    const duration = Math.round(((newEnd - newStart) / (1000 * 60 * 60)) * 2) / 2
    
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