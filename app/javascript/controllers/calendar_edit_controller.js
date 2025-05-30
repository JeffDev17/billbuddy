import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["modal", "form", "recurringOptions", "eventSummary", "eventLocation", "eventDescription", "eventDate", "startTime", "endTime", "startTimeHidden", "endTimeHidden"]

  connect() {
    this.populateEditTimeSelects()
    
    // Listen for successful form submissions
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

  // Função para preencher os selects de horário na edição
  populateEditTimeSelects() {
    const times = this.generateTimeOptions();
    
    if (this.hasStartTimeTarget) {
      this.startTimeTarget.innerHTML = '';
      times.forEach(time => {
        this.startTimeTarget.add(new Option(time, time));
      });
    }
    
    if (this.hasEndTimeTarget) {
      this.endTimeTarget.innerHTML = '';
      times.forEach(time => {
        this.endTimeTarget.add(new Option(time, time));
      });
    }
  }

  editEvent(event) {
    const eventId = event.params.eventId;
    
    // Atualizar a action do formulário com o ID do evento
    this.formTarget.action = `/calendars/update_event/${eventId}`;
    
    // Adicionar parâmetro de data se disponível
    const dateElement = document.querySelector('input[name="date"]');
    if (dateElement) {
      this.formTarget.action += `?date=${dateElement.value}`;
    }
    
    // Encontrar o evento na lista de eventos
    const eventDiv = document.querySelector(`[data-event-id="${eventId}"]`);
    
    if (eventDiv) {
      // Preencher o formulário com os dados do evento
      this.eventSummaryTarget.value = eventDiv.dataset.summary;
      this.eventLocationTarget.value = eventDiv.dataset.location;
      this.eventDescriptionTarget.value = eventDiv.dataset.description;
      
      // Separar a data e hora do datetime
      const startDateTime = new Date(eventDiv.dataset.startTime);
      const endDateTime = new Date(eventDiv.dataset.endTime);
      
      // Formatar a data para o campo date
      const dateStr = startDateTime.toISOString().split('T')[0];
      this.eventDateTarget.value = dateStr;
      
      // Formatar os horários para os selects (considerando UTC-3)
      const startTimeStr = this.formatTimeForSelect(startDateTime);
      const endTimeStr = this.formatTimeForSelect(endDateTime);
      
      // Preencher os selects de horário
      this.populateEditTimeSelects();
      this.startTimeTarget.value = startTimeStr;
      this.endTimeTarget.value = endTimeStr;
      
      // Atualizar os campos hidden
      this.updateEditDateTime();
      
      // Mostrar opções de evento recorrente se o evento for recorrente
      if (eventDiv.dataset.recurringEventId) {
        this.recurringOptionsTarget.classList.remove('hidden');
      } else {
        this.recurringOptionsTarget.classList.add('hidden');
      }
    }
    
    this.modalTarget.classList.remove('hidden');
  }

  // Função para formatar o horário considerando o fuso de Brasília
  formatTimeForSelect(date) {
    const hours = date.getHours().toString().padStart(2, '0');
    const minutes = date.getMinutes().toString().padStart(2, '0');
    return `${hours}:${minutes}`;
  }

  // Função para atualizar os campos hidden na edição
  updateEditDateTime() {
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

  closeModal() {
    this.modalTarget.classList.add('hidden');
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
    }
  }
}