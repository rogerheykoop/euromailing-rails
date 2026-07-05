require "active_job"

module Euromailing
  # Background worker behind Euromailing::Syncable. Kept deliberately
  # dumb: refetch the record (upsert) or take the captured email (delete),
  # call the API, let ActiveJob's retry_on handle transient failures.
  class SyncJob < ActiveJob::Base
    queue_as :default

    retry_on Euromailing::ApiError, wait: :polynomially_longer, attempts: 5
    discard_on ActiveJob::DeserializationError

    def perform(action, *args)
      case action
      when "upsert" then upsert(*args)
      when "delete" then Euromailing.client.delete_contact(email: args.first)
      else raise ArgumentError, "unknown sync action #{action.inspect}"
      end
    rescue Euromailing::ApiError => e
      # 404 on delete means the contact never existed — mission accomplished.
      raise unless action == "delete" && e.status == 404
    end

    private

    def upsert(class_name, id)
      record = class_name.constantize.find_by(id: id)
      return if record.nil? || !record.euromailing_sync?

      attributes = record.euromailing_contact_attributes.transform_keys(&:to_sym)
      Euromailing.client.upsert_contact(**attributes.slice(:email, :first_name, :last_name, :custom_fields))

      record.euromailing_sync_options[:lists].each do |list_id|
        Euromailing.client.subscribe(list_id: list_id, email: attributes[:email])
      end
    end
  end
end
