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
    "debugInfo"
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
} 