import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["modal", "recurringOptions"]
  static values = { currentEventId: String }

  deleteEvent(event) {
    this.currentEventIdValue = event.params.eventId;
    const isRecurring = event.params.isRecurring;
    
    // Convert string to boolean properly
    const isRecurringBool = isRecurring === 'true' || isRecurring === true;
    
    if (isRecurringBool) {
      this.recurringOptionsTarget.classList.remove('hidden');
    } else {
      this.recurringOptionsTarget.classList.add('hidden');
    }
    
    this.modalTarget.classList.remove('hidden');
  }

  closeModal() {
    this.modalTarget.classList.add('hidden');
    this.currentEventIdValue = '';
  }

  confirmDelete() {
    if (!this.currentEventIdValue) return;
    
    const deleteType = document.querySelector('input[name="delete_type"]:checked')?.value || 'single';
    const form = document.createElement('form');
    form.method = 'POST';
    form.action = `/calendars/delete_event/${this.currentEventIdValue}`;
    
    // Make the form submit remotely with Turbo Stream
    form.setAttribute('data-remote', 'true');
    form.setAttribute('data-turbo', 'true');
    
    // Add headers for Turbo Stream
    const turboHeader = document.createElement('input');
    turboHeader.type = 'hidden';
    turboHeader.name = 'HTTP_ACCEPT';
    turboHeader.value = 'text/vnd.turbo-stream.html';
    form.appendChild(turboHeader);
    
    // Adicionar o token CSRF
    const csrfToken = document.querySelector('meta[name="csrf-token"]').content;
    const csrfInput = document.createElement('input');
    csrfInput.type = 'hidden';
    csrfInput.name = 'authenticity_token';
    csrfInput.value = csrfToken;
    form.appendChild(csrfInput);
    
    // Adicionar o método DELETE
    const methodInput = document.createElement('input');
    methodInput.type = 'hidden';
    methodInput.name = '_method';
    methodInput.value = 'DELETE';
    form.appendChild(methodInput);
    
    // Adicionar o tipo de deleção para eventos recorrentes
    const deleteTypeInput = document.createElement('input');
    deleteTypeInput.type = 'hidden';
    deleteTypeInput.name = 'delete_type';
    deleteTypeInput.value = deleteType;
    form.appendChild(deleteTypeInput);
    
    // Add the current date to maintain context
    const dateElement = document.querySelector('input[name="date"]');
    if (dateElement) {
      const dateInput = document.createElement('input');
      dateInput.type = 'hidden';
      dateInput.name = 'date';
      dateInput.value = dateElement.value;
      form.appendChild(dateInput);
    }
    
    // Add success listener to close modal
    form.addEventListener('ajax:success', () => {
      this.closeModal();
      this.refreshCalendarIframe();
    });

    form.addEventListener('turbo:submit-end', (event) => {
      if (event.detail.success) {
        this.closeModal();
        this.refreshCalendarIframe();
      }
    });
    
    document.body.appendChild(form);
    
    // Submit using fetch to ensure proper headers
    const formData = new FormData(form);
    
    fetch(form.action, {
      method: 'DELETE',
      body: formData,
      headers: {
        'Accept': 'text/vnd.turbo-stream.html',
        'X-Requested-With': 'XMLHttpRequest'
      }
    }).then(response => {
      if (response.ok) {
        this.closeModal();
        this.refreshCalendarIframe();
        // Trigger page refresh or update
        window.location.reload();
      }
    }).catch(error => {
      console.error('Delete request failed:', error);
    });
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

  // Fechar o modal se clicar fora dele
  closeOnOutsideClick(event) {
    if (event.target === this.modalTarget) {
      this.modalTarget.classList.add('hidden');
      this.currentEventIdValue = '';
    }
  }
} 