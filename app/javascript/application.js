// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails

// Import Turbo and configure it
import "@hotwired/turbo-rails"
import { Turbo } from "@hotwired/turbo-rails"

// Import Stimulus controllers
import "controllers"

// Import scroll position preservation
import "scroll_position"

// Import appointment modal functions
import "appointment_modals"

// Configure Turbo
Turbo.config.drive.progressBarDelay = 100
Turbo.session.drive = true

// Charts - loaded synchronously for better compatibility
import "chart.js"
import "chartjs-adapter-date-fns"
import "chartkick"

// Chart loading functionality - only for metrics page
function loadChartsIfNeeded() {
  // Check if we're on the metrics page
  const currentPath = window.location.pathname
  if (!currentPath.includes('/calendars/metrics')) {
    return
  }

  try {
    console.log("Configuring charts for metrics page...")
    
    // Charts are already imported synchronously, just verify they're available
    if (typeof window.Chart === 'undefined') {
      throw new Error("Chart.js not available")
    }
    
    if (typeof window.Chartkick === 'undefined') {
      throw new Error("Chartkick not available") 
    }
    
    // Verify date adapter is available for time-based charts
    console.log("Chart.js adapters available:", window.Chart._adapters || "Not available")
    
    // Configure Chartkick with Chart.js
    if (typeof window.Chartkick.use === 'function') {
      window.Chartkick.use(window.Chart)
      console.log("Chartkick configured with Chart.js successfully")
    }
    
    console.log("Charts ready for metrics page")
    
  } catch (error) {
    console.error("Failed to configure charts:", error)
    showChartErrorMessage()
  }
}

function showChartLoadingIndicators() {
  const chartContainers = document.querySelectorAll('[id^="chart-"]')
  chartContainers.forEach(container => {
    const loadingDiv = document.createElement('div')
    loadingDiv.className = 'chart-loading absolute inset-0 flex items-center justify-center bg-white bg-opacity-90 dark:bg-gray-800 dark:bg-opacity-90 z-10'
    loadingDiv.innerHTML = `
      <div class="text-center">
        <div class="animate-spin rounded-full h-8 w-8 border-b-2 border-indigo-600 mx-auto mb-2"></div>
        <p class="text-sm text-gray-600 dark:text-gray-400">Carregando gráfico...</p>
      </div>
    `
    container.appendChild(loadingDiv)
  })
}

function hideChartLoadingIndicators() {
  const loadingIndicators = document.querySelectorAll('.chart-loading')
  loadingIndicators.forEach(indicator => indicator.remove())
}

function showChartErrorMessage() {
  const chartContainers = document.querySelectorAll('[id^="chart-"]')
  chartContainers.forEach(container => {
    const existingLoading = container.querySelector('.chart-loading')
    if (existingLoading) {
      existingLoading.innerHTML = `
        <div class="text-center">
          <p class="text-sm text-red-600 dark:text-red-400">❌ Erro ao carregar gráficos</p>
          <p class="text-xs text-gray-500 dark:text-gray-400 mt-1">Os dados ainda estão disponíveis nos cards acima</p>
        </div>
      `
    }
  })
}

// Load charts on initial page load
document.addEventListener("DOMContentLoaded", loadChartsIfNeeded)

// Load charts after Turbo navigation
document.addEventListener("turbo:load", () => {
  loadChartsIfNeeded()
  
  // Refresh existing charts if any
  if (typeof Chartkick !== 'undefined' && Chartkick.charts) {
    Object.values(Chartkick.charts).forEach(chart => {
      if (chart && chart.redraw) {
        chart.redraw()
      }
    })
  }
})
