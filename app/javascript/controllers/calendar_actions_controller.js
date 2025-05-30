import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  editEvent(event) {
    const eventId = event.params.eventId
    
    // Dispatch to the edit controller
    const editController = this.application.getControllerForElementAndIdentifier(
      document.querySelector('[data-controller~="calendar-edit"]'),
      'calendar-edit'
    )
    
    if (editController) {
      editController.editEvent(event)
    }
  }

  deleteEvent(event) {
    const eventId = event.params.eventId
    const isRecurring = event.params.isRecurring
    
    // Dispatch to the delete controller
    const deleteController = this.application.getControllerForElementAndIdentifier(
      document.querySelector('[data-controller~="calendar-delete"]'),
      'calendar-delete'
    )
    
    if (deleteController) {
      deleteController.deleteEvent(event)
    }
  }
} 