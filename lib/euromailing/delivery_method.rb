require "base64"

module Euromailing
  # ActionMailer delivery method. Register happens automatically via the
  # Railtie; configure with:
  #
  #   config.action_mailer.delivery_method = :euromailing
  #   config.action_mailer.euromailing_settings = { api_key: "eml_live_…" }
  #
  # When no per-mailer settings are given, the global Euromailing
  # configuration is used.
  class DeliveryMethod
    class DeliveryError < Euromailing::Error; end

    attr_reader :settings

    def initialize(settings = {})
      @settings = settings || {}
    end

    def deliver!(mail)
      # Assigns content-ids to inline attachments and finalizes parts —
      # Mail normally does this during encoding, but we read the message
      # fields before that point. Idempotent.
      mail.ready_to_send!

      recipients = Array(mail.to)
      unless recipients.size == 1
        raise DeliveryError,
              "Euromailing transactional mail takes exactly one recipient per message (got #{recipients.size})"
      end

      client.deliver_transactional(
        from:        mail[:from].to_s,
        to:          recipients.first,
        subject:     mail.subject.to_s,
        html_body:   body_part(mail, "text/html"),
        text_body:   body_part(mail, "text/plain"),
        reply_to:    mail[:reply_to]&.to_s,
        attachments: serialized_attachments(mail)
      )
    end

    private

    def client
      if settings[:api_key]
        config = Configuration.new
        config.api_key  = settings[:api_key]
        config.base_url = settings[:base_url] if settings[:base_url]
        Client.new(config)
      else
        Euromailing.client
      end
    end

    def body_part(mail, mime_type)
      part = mime_type == "text/html" ? mail.html_part : mail.text_part
      return part.decoded if part
      return nil if mail.multipart?

      # A bare `body "…"` mail carries no explicit Content-Type until it
      # is encoded; Mail treats that as text/plain.
      (mail.mime_type || "text/plain") == mime_type ? mail.decoded : nil
    end

    def serialized_attachments(mail)
      return nil if mail.attachments.empty?

      mail.attachments.map do |attachment|
        serialized = {
          filename:     attachment.filename,
          content_type: attachment.mime_type,
          content:      Base64.strict_encode64(attachment.body.decoded)
        }
        # ActionMailer's attachments.inline[...] become CID images: pass
        # the content id (sans Mail's angle brackets) so the API builds a
        # multipart/related message and <img src="cid:..."> resolves.
        if attachment.inline? && attachment.content_id
          serialized[:content_id] = attachment.content_id.gsub(/\A<|>\z/, "")
        end
        serialized
      end
    end
  end
end
