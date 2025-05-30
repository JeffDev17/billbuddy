import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  navigate() {
    const selectedDate = this.element.value;
    if (selectedDate) {
      // Navigate to the selected date using Turbo
      window.Turbo.visit(`/calendars?date=${selectedDate}`);
    }
  }
} 