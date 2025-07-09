// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails

// Import Turbo and configure it
import "@hotwired/turbo-rails"
import { Turbo } from "@hotwired/turbo-rails"

// Import Stimulus controllers
import "controllers"

// Import scroll position preservation
import "./scroll_position"

// Configure Turbo
Turbo.config.drive.progressBarDelay = 100
Turbo.session.drive = true

// TODO: Re-enable charts after fixing core functionality
// import "chart.js"
// import Chartkick from "chartkick"

// Chart loading functionality - only for metrics page
async function loadChartsIfNeeded() {
  // Check if we're on the metrics page
  const currentPath = window.location.pathname
  if (!currentPath.includes('/calendars/metrics')) {
    return
  }

  // Show loading indicators
  showChartLoadingIndicators()

  try {
    // Load Chart.js first
    console.log("Loading Chart.js...")
    const chartModule = await import("chart.js")
    const Chart = chartModule.default
    
    if (!Chart) {
      throw new Error("Chart.js failed to load properly")
    }
    
    // Make Chart globally available for Chartkick
    window.Chart = Chart
    console.log("Chart.js loaded and made available globally")
    
    // Try to load date adapter
    try {
      await import("chartjs-adapter-date-fns")
      console.log("Date adapter loaded successfully")
    } catch (dateAdapterError) {
      console.warn("Date adapter failed to load, some time-based charts may not work:", dateAdapterError)
    }
    
    // Now load Chartkick
    console.log("Loading Chartkick...")
    const chartkickModule = await import("chartkick")
    const Chartkick = chartkickModule.default
    
    if (!Chartkick) {
      throw new Error("Chartkick failed to load properly")
    }
    
    // Configure Chartkick with Chart.js
    Chartkick.use(Chart)
    
    // Make Chartkick globally available
    window.Chartkick = Chartkick
    
    console.log("Charts configured successfully for metrics page")
    
    // Hide loading indicators after a short delay to let charts render
    setTimeout(hideChartLoadingIndicators, 1500)
    
  } catch (error) {
    console.error("Failed to load charts:", error)
    // Show error message instead of loading indicators
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
