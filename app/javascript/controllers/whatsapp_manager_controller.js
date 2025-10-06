import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "statusText", 
    "statusDot",
    "messages", 
    "loadingState", 
    "qrContainer", 
    "qrCode", 
    "successState", 
    "errorState", 
    "errorMessage", 
    "debugInfo",
    "reminderToggle",
    "statTotal",
    "statSent",
    "statPending",
    "statFailed",
    "remindersList"
  ]

  connect() {
    console.log('🚀 WhatsApp Manager iniciando...')
    this.qrCodeInstance = null
    this.statusCheckInterval = null
    this.currentQrCode = null
    this.isQrCodeDisplayed = false
    this.startStatusCheck()
  }

  disconnect() {
    this.stopIntervals()
  }

  // Service management actions
  async startService() {
    await this.serviceAction('start')
  }

  async restartService() {
    await this.serviceAction('restart')
  }

  async stopService() {
    await this.serviceAction('stop')
  }

  async serviceAction(action) {
    console.log(`🔧 Executando ação: ${action}`)
    this.updateStatus('🔄 Processando...')
    
    try {
      const response = await fetch(`/whatsapp/${action}`, { 
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content
        }
      })
      
      const data = await response.json()
      console.log(`✅ Resposta da ação ${action}:`, data)
      
      if (data.success) {
        this.showMessage(data.message, 'success')
        setTimeout(() => this.checkStatus(), 2000)
      } else {
        this.showMessage(data.error || 'Erro na operação', 'error')
      }
    } catch (error) {
      console.error(`❌ Erro na ação ${action}:`, error)
      this.showMessage('Erro de comunicação com o servidor', 'error')
    }
  }

  async checkStatus() {
    try {
      console.log('📡 Verificando status...')
      const response = await fetch('/whatsapp/status')
      const data = await response.json()
      
      console.log('📊 Status recebido:', data)
      this.updateDebugInfo('Status', data)
      
      if (data.authenticated || data.state === 'CONNECTED') {
        this.showSuccess()
        this.updateStatus('🟢 WhatsApp conectado e pronto')
        this.stopIntervals()
        return
      }
      
      if (data.status === 'initializing') {
        this.updateStatus('🟡 Serviço inicializando...')
        this.showLoading('Serviço inicializando, aguarde...')
        // Only try to get QR code after service has been initializing for a while
        setTimeout(() => {
          if (!this.isQrCodeDisplayed && data.status === 'initializing') {
            this.getQRCode()
          }
        }, 15000) // Wait 15 seconds before requesting QR
      } else if (data.status === 'ready' || data.status === 'pending') {
        this.updateStatus('🟡 Serviço ativo, aguardando autenticação')
        if (!this.isQrCodeDisplayed) {
          this.getQRCode()
        }
      } else if (data.error) {
        this.showError(`Erro no serviço: ${data.error}`)
        this.updateStatus('🔴 Erro no serviço')
        this.stopIntervals() // Stop polling on service error
      } else {
        this.updateStatus('⚪ Serviço parado')
        this.showError('Serviço WhatsApp parado')
        this.stopIntervals() // Stop polling when service is stopped
      }
      
    } catch (error) {
      console.error('❌ Erro ao verificar status:', error)
      this.updateStatus('🔴 Erro de conexão')
      this.updateDebugInfo('Erro Status', error.message)
      this.showError('Erro de conexão com o servidor')
    }
  }

  refreshQRCode() {
    console.log('🔄 Forçando refresh do QR Code...')
    this.isQrCodeDisplayed = false
    this.currentQrCode = null
    this.getQRCode()
  }

  async getQRCode() {
    // Don't request QR code if we're already showing one or in error state
    if (this.isQrCodeDisplayed || this.errorStateTarget.style.display !== 'none') {
      return
    }

    try {
      console.log('📱 Buscando QR Code...')
      const response = await fetch('/whatsapp/qr-code')
      const data = await response.json()
      
      console.log('🔳 QR Code recebido:', data)
      this.updateDebugInfo('QR Code', data)
      
      if (data.status === 'ready' && data.authenticated) {
        this.showSuccess()
        this.stopIntervals()
        return
      }
      
      if (data.qr && data.qr.length > 0) {
        this.showQRCode(data.qr)
      } else if (data.status === 'pending') {
        this.showLoading('QR Code sendo gerado...')
      } else if (data.status === 'initializing') {
        this.showLoading('Serviço inicializando, aguarde...')
      } else if (data.error) {
        this.showError(`Erro ao obter QR Code: ${data.error}`)
        this.stopIntervals() // Stop polling on error
      } else {
        this.showLoading('Aguardando QR Code...')
      }
      
    } catch (error) {
      console.error('❌ Erro ao obter QR Code:', error)
      this.updateDebugInfo('Erro QR', error.message)
      this.showError('Erro de comunicação ao obter QR Code')
      this.stopIntervals() // Stop polling on error
    }
  }

  showQRCode(qrData) {
    // Don't regenerate if it's the same QR code
    if (this.currentQrCode === qrData && this.isQrCodeDisplayed) {
      console.log('🔳 QR Code já exibido, pulando regeneração')
      return
    }
    
    console.log('🔳 Exibindo novo QR Code')
    this.currentQrCode = qrData
    this.isQrCodeDisplayed = true
    
    this.hideAllStates()
    this.qrContainerTarget.style.display = 'block'
    
    this.qrCodeTarget.innerHTML = ''
    
    // Load QRCode library dynamically if not available
    if (typeof QRCode === 'undefined') {
      this.loadQRCodeLibrary().then(() => {
        this.generateQRCode(qrData)
      })
    } else {
      this.generateQRCode(qrData)
    }
    
    // Reduce polling frequency now that QR code is displayed
    this.adjustCheckFrequency()
  }

  async loadQRCodeLibrary() {
    return new Promise((resolve, reject) => {
      if (document.querySelector('script[src*="qrcode"]')) {
        resolve()
        return
      }
      
      const script = document.createElement('script')
      script.src = 'https://cdnjs.cloudflare.com/ajax/libs/qrcodejs/1.0.0/qrcode.min.js'
      script.onload = resolve
      script.onerror = reject
      document.head.appendChild(script)
    })
  }

  generateQRCode(qrData) {
    try {
      this.qrCodeInstance = new QRCode(this.qrCodeTarget, {
        text: qrData,
        width: 256,
        height: 256,
        colorDark: '#000000',
        colorLight: '#ffffff'
      })
    } catch (error) {
      console.error('Erro ao gerar QR Code:', error)
      // Fallback para URL externa
      this.qrCodeTarget.innerHTML = `
        <img src="https://api.qrserver.com/v1/create-qr-code/?size=256x256&data=${encodeURIComponent(qrData)}" 
             alt="QR Code do WhatsApp" 
             class="mx-auto rounded-lg shadow-md border border-gray-200 dark:border-gray-700"
             style="width: 256px; height: 256px;" />
      `
    }
  }

  showLoading(message = 'Carregando...') {
    console.log('⏳ Mostrando loading:', message)
    this.hideAllStates()
    this.loadingStateTarget.style.display = 'block'
    this.loadingStateTarget.querySelector('p').textContent = message
  }

  showSuccess() {
    console.log('✅ Mostrando sucesso')
    this.hideAllStates()
    this.successStateTarget.style.display = 'block'
    this.updateStatus('🟢 Serviço ativo e autenticado')
  }

  showError(message) {
    console.log('❌ Mostrando erro:', message)
    this.hideAllStates()
    this.errorStateTarget.style.display = 'block'
    this.errorMessageTarget.textContent = message
    this.updateStatus('🔴 Erro no serviço')
  }

  hideAllStates() {
    const wasQrDisplayed = this.qrContainerTarget.style.display !== 'none'
    
    this.loadingStateTarget.style.display = 'none'
    this.qrContainerTarget.style.display = 'none'
    this.successStateTarget.style.display = 'none'
    this.errorStateTarget.style.display = 'none'
    
    // Reset QR code state only when actually hiding the QR container
    if (wasQrDisplayed) {
      this.isQrCodeDisplayed = false
      this.currentQrCode = null
      console.log('🔳 QR Code state reset')
    }
  }

  updateStatus(text) {
    this.statusTextTarget.textContent = text
    
    // Update status dot color based on message
    if (this.hasStatusDotTarget) {
      this.statusDotTarget.className = this.statusDotTarget.className.replace(/bg-\w+-\d+/, '')
      
      if (text.includes('🟢') || text.includes('autenticado')) {
        this.statusDotTarget.classList.add('bg-green-500')
        this.statusDotTarget.classList.remove('animate-pulse')
      } else if (text.includes('🟡') || text.includes('QR')) {
        this.statusDotTarget.classList.add('bg-yellow-500', 'animate-pulse')
      } else if (text.includes('🔴') || text.includes('Erro')) {
        this.statusDotTarget.classList.add('bg-red-500', 'animate-pulse')
      } else {
        this.statusDotTarget.classList.add('bg-blue-500', 'animate-pulse')
      }
    }
  }

  showMessage(message, type) {
    const alertClass = type === 'success' ? 'alert-success' : 'alert-danger'
    this.messagesTarget.innerHTML = `<div class="alert ${alertClass}">${message}</div>`
    setTimeout(() => this.messagesTarget.innerHTML = '', 5000)
  }

  updateDebugInfo(label, data) {
    const timestamp = new Date().toLocaleTimeString()
    const info = `[${timestamp}] ${label}: ${JSON.stringify(data, null, 2)}\n`
    this.debugInfoTarget.textContent = info + this.debugInfoTarget.textContent.slice(0, 1000)
  }

  startStatusCheck() {
    this.checkStatus()
    this.statusCheckInterval = setInterval(() => this.checkStatus(), 10000) // Start with 10s interval
  }
  
  // Reduce check frequency when QR code is displayed
  adjustCheckFrequency() {
    if (this.statusCheckInterval) {
      clearInterval(this.statusCheckInterval)
    }
    
    const frequency = this.isQrCodeDisplayed ? 30000 : 10000 // 30s if QR displayed, 10s otherwise
    this.statusCheckInterval = setInterval(() => this.checkStatus(), frequency)
  }

  stopIntervals() {
    if (this.statusCheckInterval) {
      clearInterval(this.statusCheckInterval)
      this.statusCheckInterval = null
    }
  }

  restart() {
    console.log('🔄 Reiniciando WhatsApp Manager...')
    this.stopIntervals()
    this.showLoading('Reiniciando...')
    setTimeout(() => this.startStatusCheck(), 1000)
  }

  async toggleReminders() {
    try {
      const response = await fetch('/whatsapp/toggle-reminders', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content
        }
      })
      
      const data = await response.json()
      
      if (data.success) {
        this.updateToggleState(data.enabled)
        this.showMessage(data.message, 'success')
      } else {
        this.showMessage(data.error || 'Erro ao alternar lembretes', 'error')
      }
    } catch (error) {
      console.error('Erro ao alternar lembretes:', error)
      this.showMessage('Erro de comunicação com o servidor', 'error')
    }
  }

  async sendSingleReminder(event) {
    const appointmentId = event.target.closest('button').dataset.appointmentId
    const button = event.target.closest('button')
    const originalHtml = button.innerHTML
    
    button.disabled = true
    button.innerHTML = '<i class="fas fa-spinner fa-spin mr-1"></i>Enviando...'

    try {
      const response = await fetch(`/whatsapp/send-reminder/${appointmentId}`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content
        }
      })
      
      const data = await response.json()
      
      if (data.success) {
        this.showMessage(data.message, 'success')
        setTimeout(() => this.refreshReminderStats(), 1000)
      } else {
        this.showMessage(data.error || 'Erro ao enviar lembrete', 'error')
        button.disabled = false
        button.innerHTML = originalHtml
      }
    } catch (error) {
      console.error('Erro ao enviar lembrete:', error)
      this.showMessage('Erro de comunicação com o servidor', 'error')
      button.disabled = false
      button.innerHTML = originalHtml
    }
  }

  async refreshReminderStats() {
    try {
      const response = await fetch('/whatsapp/reminder-stats')
      const data = await response.json()
      
      this.updateReminderStats(data.stats)
      this.updateRemindersList(data.upcoming)
      this.updateToggleState(data.enabled)
    } catch (error) {
      console.error('Erro ao atualizar estatísticas:', error)
    }
  }

  updateToggleState(enabled) {
    if (!this.hasReminderToggleTarget) return

    const toggle = this.reminderToggleTarget
    const indicator = toggle.querySelector('span')
    
    if (enabled) {
      toggle.classList.remove('bg-gray-200')
      toggle.classList.add('bg-blue-600')
      indicator.classList.remove('translate-x-1')
      indicator.classList.add('translate-x-6')
    } else {
      toggle.classList.remove('bg-blue-600')
      toggle.classList.add('bg-gray-200')
      indicator.classList.remove('translate-x-6')
      indicator.classList.add('translate-x-1')
    }
  }

  updateReminderStats(stats) {
    if (this.hasStatTotalTarget) this.statTotalTarget.textContent = stats.total_today
    if (this.hasStatSentTarget) this.statSentTarget.textContent = stats.sent_today
    if (this.hasStatPendingTarget) this.statPendingTarget.textContent = stats.pending_today
    if (this.hasStatFailedTarget) this.statFailedTarget.textContent = stats.failed_today
  }

  updateRemindersList(reminders) {
    if (!this.hasRemindersListTarget) return

    if (reminders.length === 0) {
      this.remindersListTarget.innerHTML = `
        <div class="text-center py-8 text-gray-500 dark:text-gray-400">
          <i class="fas fa-inbox text-4xl mb-2"></i>
          <p>Nenhum lembrete pendente no momento</p>
        </div>
      `
      return
    }

    this.remindersListTarget.innerHTML = reminders.map(apt => `
      <div class="flex items-center justify-between p-3 bg-gray-50 dark:bg-gray-700 rounded-lg">
        <div class="flex items-center space-x-3 flex-1">
          <div class="w-10 h-10 bg-blue-100 dark:bg-blue-900/40 rounded-full flex items-center justify-center">
            <i class="fas fa-user text-blue-600 dark:text-blue-400"></i>
          </div>
          <div>
            <p class="font-medium text-gray-900 dark:text-white">${apt.customer_name}</p>
            <p class="text-sm text-gray-600 dark:text-gray-400">
              ${apt.scheduled_at}
              <span class="text-xs">(em ${apt.minutes_until} min)</span>
            </p>
          </div>
        </div>
        <div class="flex items-center space-x-2">
          ${apt.reminded 
            ? '<span class="px-2 py-1 bg-green-100 dark:bg-green-900/40 text-green-800 dark:text-green-200 text-xs rounded-full"><i class="fas fa-check mr-1"></i>Enviado</span>'
            : `<button data-action="click->whatsapp-manager#sendSingleReminder" data-appointment-id="${apt.id}" class="px-3 py-1 bg-blue-600 hover:bg-blue-700 text-white text-xs rounded-lg transition-colors"><i class="fas fa-paper-plane mr-1"></i>Enviar</button>`
          }
        </div>
      </div>
    `).join('')
  }
} 