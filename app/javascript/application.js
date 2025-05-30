// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"

// Configure Turbo
document.addEventListener("turbo:load", () => {
  // Any global initialization can go here
})

// Ensure Turbo is properly configured
import { Turbo } from "@hotwired/turbo-rails"
Turbo.setProgressBarDelay(100) // Optional: adjust progress bar delay
Turbo.session.drive = true

// Handle Turbo Stream messages
addEventListener("turbo:before-stream-render", (event) => {
  // You can add custom handling here if needed
})
import "controllers"
