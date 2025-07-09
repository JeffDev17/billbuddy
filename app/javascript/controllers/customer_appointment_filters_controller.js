import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["statusSelect", "periodSelect", "clearButton", "appointmentSection", "appointmentItem", "statusCount"]

  connect() {
    console.log("Customer appointment filters controller connected")
    this.setupEventListeners()
  }

  setupEventListeners() {
    // Auto-apply filters when select fields change
    if (this.hasStatusSelectTarget) {
      this.statusSelectTarget.addEventListener('change', () => {
        this.applyFilters()
      })
    }

    if (this.hasPeriodSelectTarget) {
      this.periodSelectTarget.addEventListener('change', () => {
        this.applyFilters()
      })
    }

    if (this.hasClearButtonTarget) {
      this.clearButtonTarget.addEventListener('click', () => {
        this.clearFilters()
      })
    }
  }

  applyFilters() {
    const selectedStatus = this.statusSelectTarget?.value || 'all'
    const selectedPeriod = this.periodSelectTarget?.value || 'all'

    // Hide all sections first
    this.appointmentSectionTargets.forEach(section => {
      section.style.display = 'none'
    })

    // Show relevant sections based on status filter
    if (selectedStatus === 'all') {
      this.appointmentSectionTargets.forEach(section => {
        section.style.display = 'block'
      })
    } else {
      const targetSection = this.appointmentSectionTargets.find(section => 
        section.dataset.statusSection === selectedStatus
      )
      if (targetSection) {
        targetSection.style.display = 'block'
      }
    }

    // Apply period filter
    this.applyPeriodFilter(selectedPeriod)

    // Update section counts
    this.updateSectionCounts()
  }

  applyPeriodFilter(selectedPeriod) {
    if (selectedPeriod === 'all') {
      // Show all items
      this.appointmentItemTargets.forEach(item => {
        item.style.display = 'block'
      })
      return
    }

    const now = new Date()
    let startDate, endDate

    // Handle specific year filter (year_YYYY)
    if (selectedPeriod.startsWith('year_')) {
      const year = parseInt(selectedPeriod.split('_')[1])
      startDate = new Date(year, 0, 1) // January 1st
      endDate = new Date(year, 11, 31, 23, 59, 59) // December 31st
    }
    // Handle specific month filter (month_YYYY_MM)
    else if (selectedPeriod.startsWith('month_')) {
      const [_, year, month] = selectedPeriod.split('_')
      startDate = new Date(parseInt(year), parseInt(month) - 1, 1)
      endDate = new Date(parseInt(year), parseInt(month), 0, 23, 59, 59) // Last day of month
    }
    // Handle relative period filters
    else {
      switch(selectedPeriod) {
        case 'this_month':
          startDate = new Date(now.getFullYear(), now.getMonth(), 1)
          endDate = new Date(now.getFullYear(), now.getMonth() + 1, 0, 23, 59, 59)
          break
        case 'last_month':
          startDate = new Date(now.getFullYear(), now.getMonth() - 1, 1)
          endDate = new Date(now.getFullYear(), now.getMonth(), 0, 23, 59, 59)
          break
        case 'this_year':
          startDate = new Date(now.getFullYear(), 0, 1)
          endDate = new Date(now.getFullYear(), 11, 31, 23, 59, 59)
          break
        case 'last_year':
          startDate = new Date(now.getFullYear() - 1, 0, 1)
          endDate = new Date(now.getFullYear() - 1, 11, 31, 23, 59, 59)
          break
        case 'last_3_months':
          startDate = new Date(now.getFullYear(), now.getMonth() - 3, 1)
          endDate = now
          break
        case 'last_6_months':
          startDate = new Date(now.getFullYear(), now.getMonth() - 6, 1)
          endDate = now
          break
        case 'last_12_months':
          startDate = new Date(now.getFullYear(), now.getMonth() - 12, 1)
          endDate = now
          break
      }
    }

    this.appointmentItemTargets.forEach(item => {
      const appointmentDate = new Date(item.dataset.appointmentDate)
      
      if (appointmentDate >= startDate && appointmentDate <= endDate) {
        item.style.display = 'block'
      } else {
        item.style.display = 'none'
      }
    })
  }

  updateSectionCounts() {
    this.appointmentSectionTargets.forEach(section => {
      // Get all appointment items within this section
      const allItemsInSection = section.querySelectorAll('[data-customer-appointment-filters-target="appointmentItem"]')
      let visibleCount = 0

      allItemsInSection.forEach(item => {
        // Check if the item is visible (no display:none style)
        const style = window.getComputedStyle(item)
        if (style.display !== 'none') {
          visibleCount++
        }
      })

      // Find the count element within this section
      const countElement = section.querySelector('[data-customer-appointment-filters-target="statusCount"]')
      if (countElement) {
        countElement.textContent = visibleCount
      }
    })
  }

  clearFilters() {
    // Reset all select fields
    if (this.hasStatusSelectTarget) {
      this.statusSelectTarget.value = 'all'
    }

    if (this.hasPeriodSelectTarget) {
      this.periodSelectTarget.value = 'all'
    }

    // Show all sections and items
    this.appointmentSectionTargets.forEach(section => {
      section.style.display = 'block'
    })

    this.appointmentItemTargets.forEach(item => {
      item.style.display = 'block'
    })

    // Reset section counts to original values
    this.appointmentSectionTargets.forEach(section => {
      const totalItems = section.querySelectorAll('[data-customer-appointment-filters-target="appointmentItem"]').length
      const countElement = section.querySelector('[data-customer-appointment-filters-target="statusCount"]')
      if (countElement) {
        countElement.textContent = totalItems
      }
    })
  }

  disconnect() {
    console.log("Customer appointment filters controller disconnected")
  }
} 