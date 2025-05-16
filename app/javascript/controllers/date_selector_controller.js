import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  navigate(event) {
    const date = event.target.value
    const url = new URL(window.location)
    url.searchParams.set('date', date)
    
    // Prevent default behavior
    event.preventDefault()
    
    // Use Turbo visit with stream response
    Turbo.visit(`${url.pathname}?${url.searchParams.toString()}`, { 
      action: "replace",
      acceptsStreamResponse: true
    })
  }
} 