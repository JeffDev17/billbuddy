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
      console.log("🔍 Sensitive data controller found:", !!sensitiveDataController)
      if (sensitiveDataController) {
        console.log("🔗 Connecting FullCalendar with sensitive-data controller")
        sensitiveDataController.setFullCalendar(this.calendar)
      }
    }, 100)
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

    // Render the calendar
    this.calendar.render()
  }

  // Event handlers
  handleDateSelect(selectInfo) {
    console.log('Date selected:', selectInfo)
    // You can add your date selection logic here
  }

  handleEventClick(clickInfo) {
    console.log('Event clicked:', clickInfo)
    // You can add your event click logic here
  }

  handleEventDrop(dropInfo) {
    console.log('Event dropped:', dropInfo)
    // You can add your event drop logic here
  }

  handleEventResize(resizeInfo) {
    console.log('Event resized:', resizeInfo)
    // You can add your event resize logic here
  }

  toggleLoadingState(isLoading) {
    const loadingElement = document.querySelector('.calendar-loading')
    if (loadingElement) {
      if (isLoading) {
        loadingElement.classList.remove('hidden')
        loadingElement.classList.add('flex')
      } else {
        loadingElement.classList.add('hidden')
        loadingElement.classList.remove('flex')
      }
    }
  }

  showError(message) {
    console.error(message)
    // You can add UI error display logic here
  }
}