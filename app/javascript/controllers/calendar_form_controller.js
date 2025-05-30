import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["eventDate", "startTime", "endTime", "startTimeHidden", "endTimeHidden", "isRecurring", "recurringOptions"]

  connect() {
    this.populateTimeSelects()
    this.setMinDate()
    
    // Add form submission listeners
    this.element.addEventListener('ajax:success', (event) => {
      this.resetForm();
      this.hideForm();
      this.refreshCalendarIframe();
    });

    this.element.addEventListener('turbo:submit-end', (event) => {
      if (event.detail.success) {
        this.resetForm();
        this.hideForm();
        this.refreshCalendarIframe();
      }
    });

    // Watch for new flash messages (indicates successful submission) - backup method
    const flashContainer = document.getElementById('flash-messages');
    if (flashContainer) {
      const observer = new MutationObserver((mutations) => {
        mutations.forEach((mutation) => {
          if (mutation.type === 'childList' && mutation.addedNodes.length > 0) {
            // Check if a flash message was added
            const addedNode = mutation.addedNodes[0];
            if (addedNode.nodeType === Node.ELEMENT_NODE && 
                (addedNode.classList?.contains('bg-green-100') || addedNode.querySelector('.bg-green-100'))) {
              this.refreshCalendarIframe();
            }
          }
        });
      });
      observer.observe(flashContainer, { childList: true, subtree: true });
    }
  }

  // Função para gerar opções de horário em intervalos de 15 minutos
  generateTimeOptions() {
    const times = [];
    for (let hour = 0; hour < 24; hour++) {
      for (let minute = 0; minute < 60; minute += 15) {
        const hourStr = hour.toString().padStart(2, '0');
        const minuteStr = minute.toString().padStart(2, '0');
        times.push(`${hourStr}:${minuteStr}`);
      }
    }
    return times;
  }

  // Função para preencher os selects de horário
  populateTimeSelects() {
    const times = this.generateTimeOptions();
    
    this.startTimeTarget.innerHTML = '';
    this.endTimeTarget.innerHTML = '';
    
    times.forEach(time => {
      this.startTimeTarget.add(new Option(time, time));
      this.endTimeTarget.add(new Option(time, time));
    });
  }

  // Definir data mínima como hoje
  setMinDate() {
    const today = new Date().toISOString().split('T')[0];
    this.eventDateTarget.min = today;
  }

  // Função para atualizar os campos hidden de data/hora
  updateDateTime() {
    const date = this.eventDateTarget.value;
    const startTime = this.startTimeTarget.value;
    const endTime = this.endTimeTarget.value;
    
    if (date && startTime) {
      this.startTimeHiddenTarget.value = `${date}T${startTime}`;
    }
    if (date && endTime) {
      this.endTimeHiddenTarget.value = `${date}T${endTime}`;
    }
  }

  // Toggle das opções de recorrência
  toggleRecurring() {
    this.recurringOptionsTarget.classList.toggle('hidden');
  }

  // Function to toggle end date field (for compatibility with existing onclick)
  toggleEndDateField() {
    const noEndDateCheckbox = document.getElementById('no_end_date');
    const recurringUntilField = document.getElementById('recurring_until');
    
    if (noEndDateCheckbox.checked) {
      recurringUntilField.disabled = true;
      recurringUntilField.value = '';
    } else {
      recurringUntilField.disabled = false;
    }
  }

  resetForm() {
    this.element.reset();
    this.populateTimeSelects(); // Repopulate selects after reset
    this.recurringOptionsTarget.classList.add('hidden');
  }

  hideForm() {
    // Find the toggle target directly and hide it
    const formContainer = this.element.closest('[data-calendar-toggle-target="form"]');
    if (formContainer) {
      formContainer.classList.add('hidden');
    }
  }

  // Refresh the Google Calendar iframe to show updated events
  refreshCalendarIframe() {
    const iframe = document.getElementById('google-calendar-iframe');
    if (iframe) {
      // Force refresh by updating the src with a timestamp
      const currentSrc = iframe.src;
      const separator = currentSrc.includes('?') ? '&' : '?';
      iframe.src = currentSrc.split('&_refresh')[0] + separator + '_refresh=' + new Date().getTime();
    }
  }
} 