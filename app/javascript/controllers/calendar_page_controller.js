import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { selectedDate: String }

  connect() {
    this.updateCalendarIframe();
  }

  selectedDateValueChanged() {
    this.updateCalendarIframe();
  }

  // Update the Google Calendar iframe to show the selected date
  updateCalendarIframe() {
    const iframe = document.getElementById('google-calendar-iframe');
    if (iframe && this.selectedDateValue) {
      // Parse the date to get the week
      const selectedDate = new Date(this.selectedDateValue);
      const year = selectedDate.getFullYear();
      const month = String(selectedDate.getMonth() + 1).padStart(2, '0');
      const day = String(selectedDate.getDate()).padStart(2, '0');
      
      // Update the iframe src to show the selected week
      const currentSrc = iframe.src;
      // Remove any existing date parameters
      let baseUrl = currentSrc.split('&dates=')[0];
      if (baseUrl.includes('&_refresh=')) {
        baseUrl = baseUrl.split('&_refresh=')[0];
      }
      
      // Add the date parameter to center the calendar on that week
      const newSrc = `${baseUrl}&dates=${year}${month}${day}%2F${year}${month}${day}&_refresh=${new Date().getTime()}`;
      
      if (currentSrc !== newSrc) {
        iframe.src = newSrc;
      }
    }
  }
} 