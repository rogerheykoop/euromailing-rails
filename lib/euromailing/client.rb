require "net/http"
require "json"
require "uri"

module Euromailing
  # Thin HTTP client for Euromailing's v1 API. All methods return the
  # parsed JSON response (or nil for 204) and raise Euromailing::ApiError
  # on any non-2xx status.
  class Client
    def initialize(configuration = Euromailing.configuration)
      @config = configuration
    end

    # -- Transactional mail --------------------------------------------

    # Send one transactional message. Requires an API key with the
    # transactional:send scope, bound to the from-address's domain.
    def deliver_transactional(from:, to:, subject:, html_body: nil, text_body: nil,
                              reply_to: nil, headers: nil, attachments: nil)
      payload = {
        from: from, to: to, subject: subject,
        html_body: html_body, text_body: text_body,
        reply_to: reply_to, headers: headers, attachments: attachments
      }.reject { |_k, v| v.nil? }

      request(:post, "/api/v1/transactional_emails", payload)
    end

    # -- Contacts (user sync) ------------------------------------------

    # Idempotent create-or-update keyed on email.
    def upsert_contact(email:, first_name: nil, last_name: nil, custom_fields: nil)
      contact = { email: email, first_name: first_name, last_name: last_name,
                  custom_fields: custom_fields }.reject { |_k, v| v.nil? }
      request(:post, "/api/v1/contacts/upsert", contact: contact)
    end

    def delete_contact(email:)
      request(:delete, "/api/v1/contacts/by_email", email: email)
    end

    # -- Lists ----------------------------------------------------------

    def subscribe(list_id:, email:, first_name: nil, last_name: nil)
      payload = { email: email, first_name: first_name, last_name: last_name }
                .reject { |_k, v| v.nil? }
      request(:post, "/api/v1/lists/#{list_id}/memberships", payload)
    end

    def unsubscribe(list_id:, email:)
      request(:delete, "/api/v1/lists/#{list_id}/memberships", email: email)
    end

    def lists
      request(:get, "/api/v1/lists")
    end

    # -- Sending domains -----------------------------------------------
    #
    # For partner integrations that send on behalf of customer domains
    # (one account, many domains, one key with the
    # transactional:send_any_domain scope). Euromailing is the source of
    # truth for verification: create a domain, show the customer the DNS
    # records it returns, then poll status / trigger verify — never check
    # the customer's DNS yourself.
    #
    # Requires the sending_domains:read / sending_domains:write scopes.

    # Returns the domain plus ready-made `dns_records` (DKIM CNAME, SPF
    # include with a separate `include_token`, DMARC), with Dutch notes.
    def create_sending_domain(domain)
      request(:post, "/api/v1/sending_domains", domain: domain)
    end

    # Current verification status: `verified` plus a per-record breakdown.
    def sending_domain(domain)
      request(:get, "/api/v1/sending_domains/#{domain}")
    end

    # Triggers a fresh DNS check and returns the updated status.
    def verify_sending_domain(domain)
      request(:post, "/api/v1/sending_domains/#{domain}/verify")
    end

    def delete_sending_domain(domain)
      request(:delete, "/api/v1/sending_domains/#{domain}")
    end

    def sending_domains
      request(:get, "/api/v1/sending_domains")
    end

    private

    def request(method, path, payload = nil)
      @config.validate!
      uri = URI.join(@config.base_url, path)

      klass = { get: Net::HTTP::Get, post: Net::HTTP::Post, delete: Net::HTTP::Delete }.fetch(method)
      req = klass.new(uri)
      req["Authorization"] = "Bearer #{@config.api_key}"
      req["Content-Type"]  = "application/json"
      req["User-Agent"]    = "euromailing-rails/#{Euromailing::VERSION}"
      req.body = JSON.generate(payload) if payload && method != :get

      response = Net::HTTP.start(uri.hostname, uri.port,
                                 use_ssl: uri.scheme == "https",
                                 open_timeout: @config.open_timeout,
                                 read_timeout: @config.read_timeout) { |http| http.request(req) }

      handle(response)
    end

    def handle(response)
      status = response.code.to_i
      return nil if status == 204
      parsed = response.body.to_s.empty? ? nil : JSON.parse(response.body) rescue nil

      return parsed if (200..299).cover?(status)

      error = parsed.is_a?(Hash) ? parsed["error"] || {} : {}
      raise ApiError.new(
        status:  status,
        code:    error["code"],
        message: error["message"],
        body:    response.body
      )
    end
  end
end
