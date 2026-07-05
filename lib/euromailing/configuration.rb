module Euromailing
  class Configuration
    DEFAULT_BASE_URL = "https://euromailing.com".freeze

    attr_accessor :api_key, :base_url, :open_timeout, :read_timeout

    def initialize
      @base_url     = DEFAULT_BASE_URL
      @open_timeout = 5
      @read_timeout = 15
    end

    def validate!
      raise ConfigurationError, "Euromailing.configure { |c| c.api_key = ... } is required" if api_key.to_s.empty?
    end
  end

  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield configuration
      @client = nil
      configuration
    end

    def client
      @client ||= Client.new(configuration)
    end

    # Test hook: reset all global state.
    def reset!
      @configuration = nil
      @client = nil
    end
  end
end
