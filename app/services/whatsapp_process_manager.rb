require "childprocess"
require "socket"
require "net/http"
require "timeout"

class WhatsappProcessManager
  class << self
    attr_accessor :process, :port, :log_file

    def start!
      @port = 3001


      if running?
        Rails.logger.info "WhatsApp service already running and responding"
        return true
      end

      return false if @starting
      @starting = true

      begin
        thorough_cleanup
        @log_file = Rails.root.join("log", "whatsapp.log")

        Rails.logger.info "Starting WhatsApp Node.js service on port #{@port}"

        start_process
        wait_for_service

        Rails.logger.info "WhatsApp service started successfully"
        true
      rescue => e
        Rails.logger.error "Failed to start WhatsApp service: #{e.message}"
        stop!
        false
      ensure
        @starting = false
      end
    end

    def stop!
      Rails.logger.info "Stopping WhatsApp Node.js service"

      begin
        if @process && @process.respond_to?(:alive?) && @process.alive?
          @process.stop(5)
        end
      rescue ChildProcess::TimeoutError
        @process.kill! if @process.respond_to?(:kill!)
      rescue => e
        Rails.logger.error "Error stopping WhatsApp process: #{e.message}"
      ensure
        @process = nil
      end

      thorough_cleanup

      Rails.logger.info "WhatsApp service stopped"
      true
    end

    def restart!
      stop!
      sleep(3)
      start!
    end

    def running?
      begin
        if service_responding?
          return true
        end

        return false unless @process
        return false unless @process.respond_to?(:alive?)
        @process.alive?
      rescue => e
        Rails.logger.error "Error checking if WhatsApp process is running: #{e.message}"
        false
      end
    end

    def api_url
      "http://localhost:#{@port || 3001}"
    end

    def status
      return { status: "stopped", port: nil } unless running?

      begin
        response = HTTParty.get("#{api_url}/status", timeout: 5)
        JSON.parse(response.body).merge(port: @port)
      rescue => e
        { status: "error", error: e.message, port: @port }
      end
    end

    def force_restart!
      return false unless running?

      begin
        response = HTTParty.post("#{api_url}/restart", timeout: 10)
        JSON.parse(response.body)
      rescue => e
        Rails.logger.error "Error force restarting WhatsApp service: #{e.message}"
        { error: e.message }
      end
    end

    def thorough_cleanup
      Rails.logger.info "Performing thorough cleanup of WhatsApp processes"

      cleanup_port(3001)

      system("pkill -f 'whatsapp-api.*app.js' 2>/dev/null || true")
      system("pkill -f 'node.*whatsapp-api' 2>/dev/null || true")
      system("pkill -f 'node.*app\\.js' 2>/dev/null || true")

      system("pkill -f 'whatsapp.*Chromium' 2>/dev/null || true")
      system("pkill -f 'chrome.*whatsapp' 2>/dev/null || true")
      system("pkill -f 'chromium.*whatsapp' 2>/dev/null || true")
      system("pkill -f '.wwebjs_auth.*Chromium' 2>/dev/null || true")

      auth_dir = Rails.root.join("whatsapp-api", ".wwebjs_auth")
      if auth_dir.exist?
        Dir.glob(auth_dir.join("**", "*.lock")).each { |f| File.delete(f) rescue nil }
      end

      sleep(1)
    end

    private

    def cleanup_port(port)
      Rails.logger.info "Cleaning up any existing processes on port #{port}"

      pids = `lsof -ti:#{port} 2>/dev/null`.split.map(&:strip).reject(&:empty?)

      pids.each do |pid|
        begin
          process_info = `ps -p #{pid} -o comm= 2>/dev/null`.strip

          if process_info.include?("node") || process_info.include?("whatsapp")
            Rails.logger.info "Killing process #{pid} (#{process_info}) on port #{port}"
            Process.kill("TERM", pid.to_i)
            sleep(1)

            if `ps -p #{pid} 2>/dev/null`.strip != ""
              Process.kill("KILL", pid.to_i)
            end
          else
            Rails.logger.info "Skipping process #{pid} (#{process_info}) - not a Node.js process"
          end
        rescue Errno::ESRCH, Errno::EPERM => e
          Rails.logger.debug "Process #{pid} no longer exists or permission denied: #{e.message}"
        end
      end

      system("pkill -f 'whatsapp-api.*app.js' 2>/dev/null || true")

      sleep(1)
    rescue => e
      Rails.logger.warn "Error during port cleanup: #{e.message}"
    end

    def start_process
      @process = ChildProcess.build("node", "app.js")
      @process.environment["PORT"] = @port.to_s
      @process.environment["NODE_ENV"] = Rails.env
      @process.environment["FORCE_COLOR"] = "0"
      @process.cwd = Rails.root.join("whatsapp-api").to_s

      @process.io.stdout = @process.io.stderr = File.open(@log_file, "a")
      @process.detach = true

      @process.start

      sleep(3)

      unless @process&.alive?
        @process = nil
        raise "Node.js process failed to start"
      end
    end

    def wait_for_service(max_attempts: 60)
      attempts = 0

      loop do
        return true if service_responding?

        attempts += 1
        if attempts >= max_attempts
          raise "WhatsApp service did not respond after #{max_attempts} attempts"
        end

        if attempts % 10 == 0
          Rails.logger.info "Waiting for WhatsApp service... (attempt #{attempts}/#{max_attempts})"
        end

        sleep(1)
      end
    end

    def service_responding?
      return false unless @port

      begin
        response = HTTParty.get("#{api_url}/status", timeout: 5)
        response.code == 200
      rescue Errno::ECONNREFUSED, Errno::EHOSTUNREACH, Timeout::Error, HTTParty::Error
        false
      rescue => e
        Rails.logger.debug "Service responding check failed: #{e.message}"
        false
      end
    end

    def find_available_port(start_port)
      port = start_port
      loop do
        return port if port_available?(port)
        port += 1
        raise "No available ports found" if port > start_port + 100
      end
    end

    def port_available?(port)
      TCPSocket.new("localhost", port).close
      false
    rescue Errno::ECONNREFUSED
      true
    end
  end
end
