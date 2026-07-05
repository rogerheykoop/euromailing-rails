module Euromailing
  class Error < StandardError; end

  # Configuration is missing or invalid (no api_key, malformed base_url).
  class ConfigurationError < Error; end

  # The API answered with a non-2xx status. `code` carries the machine-
  # readable error code from the response envelope (e.g.
  # "from_domain_mismatch", "recipient_suppressed", "rate_limited").
  class ApiError < Error
    attr_reader :status, :code, :body

    def initialize(status:, code: nil, message: nil, body: nil)
      @status = status
      @code   = code
      @body   = body
      super(message || "Euromailing API responded #{status}#{" (#{code})" if code}")
    end
  end
end
