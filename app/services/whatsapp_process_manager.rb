require "childprocess"
require "socket"
require "net/http"
require "timeout"

class WhatsappProcessManager
  class << self
    attr_accessor :process, :port, :log_file

    def start!
      return true if running?

      # Prevent multiple startup attempts
      return false if @starting
      @starting = true

      begin
        # Always use port 3001, thoroughly clean any existing processes first
        thorough_cleanup
        @port = 3001
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
      return true unless @process

      Rails.logger.info "Stopping WhatsApp Node.js service"

      begin
        if @process.respond_to?(:alive?) && @process.alive?
          @process.stop(5) # Give it 5 seconds to gracefully stop
        end
      rescue ChildProcess::TimeoutError
        @process.kill! if @process.respond_to?(:kill!) # Force kill if it doesn't stop gracefully
      rescue => e
        Rails.logger.error "Error stopping WhatsApp process: #{e.message}"
      ensure
        @process = nil
        Rails.logger.info "WhatsApp service stopped"
      end

      # Clean up any remaining processes
      thorough_cleanup

      true
    end

    def restart!
      stop!
      sleep(3) # Give it more time
      start!
    end

    def running?
      return false unless @process
      return false unless @process.respond_to?(:alive?)

      begin
        @process.alive? && service_responding?
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

    # New method for comprehensive cleanup
    def thorough_cleanup
      Rails.logger.info "Performing thorough cleanup of WhatsApp processes"

      # Kill processes on port 3001 (more targeted approach)
      cleanup_port(3001)

      # Kill only specific WhatsApp-related node processes (more precise patterns)
      system("pkill -f 'whatsapp-api.*app.js' 2>/dev/null || true")
      system("pkill -f 'node.*whatsapp-api' 2>/dev/null || true")

      # Kill any Chrome/Chromium processes that might be stuck (WhatsApp Web uses these)
      system("pkill -f 'chrome.*whatsapp' 2>/dev/null || true")
      system("pkill -f 'chromium.*whatsapp' 2>/dev/null || true")

      # Clean up any .wwebjs_auth sessions that might be locked
      auth_dir = Rails.root.join("whatsapp-api", ".wwebjs_auth")
      if auth_dir.exist?
        Dir.glob(auth_dir.join("**", "*.lock")).each { |f| File.delete(f) rescue nil }
      end

      # Wait for cleanup to complete
      sleep(1) # Reduced from 2 seconds
    end

    private

    def cleanup_port(port)
      Rails.logger.info "Cleaning up any existing processes on port #{port}"

      # First, try to find processes on the specific port
      pids = `lsof -ti:#{port} 2>/dev/null`.split.map(&:strip).reject(&:empty?)

      pids.each do |pid|
        begin
          # Get process info before killing
          process_info = `ps -p #{pid} -o comm= 2>/dev/null`.strip

          # Only kill if it's actually a node process (not Rails)
          if process_info.include?("node") || process_info.include?("whatsapp")
            Rails.logger.info "Killing process #{pid} (#{process_info}) on port #{port}"
            Process.kill("TERM", pid.to_i) # Use TERM first, then escalate if needed
            sleep(1)

            # Check if process is still alive, then use KILL
            if `ps -p #{pid} 2>/dev/null`.strip != ""
              Process.kill("KILL", pid.to_i)
            end
          else
            Rails.logger.info "Skipping process #{pid} (#{process_info}) - not a Node.js process"
          end
        rescue Errno::ESRCH, Errno::EPERM => e
          # Process already dead or permission denied, continue
          Rails.logger.debug "Process #{pid} no longer exists or permission denied: #{e.message}"
        end
      end

      # Clean up specific node processes more carefully
      system("pkill -f 'whatsapp-api.*app.js' 2>/dev/null || true")

      # Wait a moment for cleanup
      sleep(1)
    rescue => e
      Rails.logger.warn "Error during port cleanup: #{e.message}"
    end

    def start_process
      @process = ChildProcess.build("node", "app.js")
      @process.environment["PORT"] = @port.to_s
      @process.environment["NODE_ENV"] = Rails.env
      @process.environment["FORCE_COLOR"] = "0" # Disable colors in logs
      @process.cwd = Rails.root.join("whatsapp-api").to_s

      # Redirect output to log file
      @process.io.stdout = @process.io.stderr = File.open(@log_file, "a")
      @process.detach = true

      @process.start

      # Give the process more time to start
      sleep(3)

      unless @process&.alive?
        @process = nil
        raise "Node.js process failed to start"
      end
    end

    def wait_for_service(max_attempts: 60) # Increased from 45 to 60 (1 minute)
      attempts = 0

      loop do
        return true if service_responding?

        attempts += 1
        if attempts >= max_attempts
          raise "WhatsApp service did not respond after #{max_attempts} attempts"
        end

        # Log progress every 10 attempts
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
