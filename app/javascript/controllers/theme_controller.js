import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.updateThemeIcon()
  }

  toggle() {
    if (document.documentElement.classList.contains('dark')) {
      document.documentElement.classList.remove('dark')
      localStorage.theme = 'light'
    } else {
      document.documentElement.classList.add('dark')
      localStorage.theme = 'dark'
    }
    this.updateThemeIcon()
  }

  updateThemeIcon() {
    const themeIcon = document.getElementById('theme-icon')
    if (themeIcon) {
      if (document.documentElement.classList.contains('dark')) {
        themeIcon.className = 'fas fa-sun'
      } else {
        themeIcon.className = 'fas fa-moon'
      }
    }
  }
} 