require "active_support/concern"
require "active_support/core_ext/class/attribute"

module Euromailing
  # Mirrors a model (typically User) as a Euromailing contact. The model
  # implements #euromailing_contact_attributes; creates/updates upsert the
  # contact (and subscribe it to the configured lists), destroys delete it.
  # All API traffic runs through Euromailing::SyncJob in the background.
  #
  #   class User < ApplicationRecord
  #     include Euromailing::Syncable
  #     euromailing_sync lists: ["<list-uuid>"], if: ->(u) { u.newsletter? }
  #
  #     def euromailing_contact_attributes
  #       { email: email, first_name: first_name, last_name: last_name,
  #         custom_fields: { plan: plan } }
  #     end
  #   end
  module Syncable
    extend ActiveSupport::Concern

    included do
      class_attribute :euromailing_sync_options, instance_writer: false, default: {}

      after_commit :euromailing_enqueue_upsert, on: %i[create update]
      after_commit :euromailing_enqueue_delete, on: :destroy
    end

    class_methods do
      # lists: list UUIDs the contact is subscribed to on every sync.
      # if:    optional proc deciding per record whether to sync at all.
      def euromailing_sync(lists: [], if: nil)
        self.euromailing_sync_options = { lists: Array(lists), if: binding.local_variable_get(:if) }
      end
    end

    def euromailing_contact_attributes
      raise NotImplementedError, "#{self.class} must implement #euromailing_contact_attributes"
    end

    def euromailing_sync?
      condition = euromailing_sync_options[:if]
      condition.nil? || !!condition.call(self)
    end

    private

    def euromailing_enqueue_upsert
      return unless euromailing_sync?

      Euromailing::SyncJob.perform_later("upsert", self.class.name, id.to_s)
    end

    def euromailing_enqueue_delete
      # The record is gone after this commit — capture the email now.
      email = euromailing_contact_attributes[:email] || euromailing_contact_attributes["email"]
      return if email.to_s.empty?

      Euromailing::SyncJob.perform_later("delete", email)
    end
  end
end
