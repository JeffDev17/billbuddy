import { Controller } from "@hotwired/stimulus"

// WhatsApp Status Indicator for Navbar
export default class extends Controller {
  static targets = ["indicator", "dot", "tooltip", "tooltipText"]

  connect() {
    console.log('📡 WhatsApp Status Indicator iniciando...')
    this.checkStatus()
    this.startStatusCheck()
  }

  disconnect() {
    if (this.statusCheckInterval) {
      clearInterval(this.statusCheckInterval)
    }
  }

  startStatusCheck() {
    // Check status every 30 seconds
    this.statusCheckInterval = setInterval(() => {
      this.checkStatus()
    }, 30000)
  }

  async checkStatus() {
    try {
      const response = await fetch('/whatsapp/status', {
        headers: {
          'Accept': 'application/json'
        }
      })
      
      const data = await response.json()
      this.updateStatusIndicator(data)
    } catch (error) {
      console.error('Erro ao verificar status do WhatsApp:', error)
      this.updateStatusIndicator({ status: 'error', error: 'Falha na comunicação' })
    }
  }

  updateStatusIndicator(data) {
    const { status, authenticated, error, state } = data
    
    console.log('🔄 Updating WhatsApp status:', { status, authenticated, error, state })
    
    // Clear all color classes first
    this.dotTarget.classList.remove('bg-red-500', 'bg-green-500', 'bg-yellow-500', 'bg-blue-500', 'bg-gray-400')
    this.indicatorTarget.classList.remove('bg-red-500/10', 'bg-green-500/10', 'bg-yellow-500/10', 'bg-blue-500/10', 'bg-gray-400/10')
    this.indicatorTarget.classList.remove('hover:bg-red-500/20', 'hover:bg-green-500/20', 'hover:bg-yellow-500/20', 'hover:bg-blue-500/20', 'hover:bg-gray-400/20')
    
    let statusText, statusColor, bgColor
    
    if ((status === 'ready' && authenticated === true) || state === 'CONNECTED') {
      statusColor = 'bg-green-500'
      bgColor = 'bg-green-500/10 hover:bg-green-500/20'
      statusText = 'WhatsApp conectado e pronto'
      console.log('✅ WhatsApp is connected - setting green status')
    } else if (status === 'pending') {
      statusColor = 'bg-yellow-500'
      bgColor = 'bg-yellow-500/10 hover:bg-yellow-500/20'
      statusText = 'WhatsApp aguardando QR Code'
      console.log('🟡 WhatsApp is pending - setting yellow status')
    } else if (status === 'initializing') {
      statusColor = 'bg-blue-500'
      bgColor = 'bg-blue-500/10 hover:bg-blue-500/20'
      statusText = 'WhatsApp inicializando...'
      console.log('🔵 WhatsApp is initializing - setting blue status')
    } else if (status === 'stopped' || status === 'error') {
      statusColor = 'bg-red-500'
      bgColor = 'bg-red-500/10 hover:bg-red-500/20'
      statusText = error ? `Erro: ${error}` : 'WhatsApp desconectado'
      console.log('🔴 WhatsApp is stopped/error - setting red status')
    } else {
      statusColor = 'bg-gray-400'
      bgColor = 'bg-gray-400/10 hover:bg-gray-400/20'
      statusText = 'Status do WhatsApp desconhecido'
      console.log('⚪ WhatsApp status unknown - setting gray status')
    }
    
    // Apply colors
    this.dotTarget.classList.add(statusColor)
    
    // Apply background color classes
    const bgClasses = bgColor.split(' ')
    bgClasses.forEach(cls => {
      if (cls.trim()) {
        this.indicatorTarget.classList.add(cls.trim())
      }
    })
    
    // Update tooltip text
    this.tooltipTextTarget.textContent = statusText
    
    console.log('🎨 Applied classes:', { dot: this.dotTarget.className, indicator: this.indicatorTarget.className })
    
    // Add pulse animation for non-ready states
    if (!((status === 'ready' && authenticated) || state === 'CONNECTED')) {
      this.dotTarget.classList.add('animate-pulse')
    } else {
      this.dotTarget.classList.remove('animate-pulse')
    }
  }

  toggleTooltip() {
    this.tooltipTarget.classList.toggle('hidden')
    
    // Auto-hide after 3 seconds
    if (!this.tooltipTarget.classList.contains('hidden')) {
      setTimeout(() => {
        this.tooltipTarget.classList.add('hidden')
      }, 3000)
    }
  }

  // Hide tooltip when clicking outside
  hideTooltip(event) {
    if (!this.element.contains(event.target)) {
      this.tooltipTarget.classList.add('hidden')
    }
  }
}
