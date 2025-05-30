require 'google/apis/calendar_v3'

# Silence only Google API logging
Google::Apis.logger = Logger.new("/dev/null")

# Configure HTTP client logging to show basic request info
if defined?(HTTPClient)
  HTTPClient.class_eval do
    def self.logger
      @logger ||= Logger.new(STDOUT).tap do |logger|
        logger.level = Logger::ERROR
      end
    end
  end
end 