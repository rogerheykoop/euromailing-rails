module Euromailing
  class Railtie < ::Rails::Railtie
    # config.euromailing.api_key = Rails.application.credentials.dig(:euromailing, :api_key)
    config.euromailing = ActiveSupport::OrderedOptions.new

    initializer "euromailing.configure" do |app|
      options = app.config.euromailing
      Euromailing.configure do |c|
        c.api_key  = options.api_key  if options.api_key
        c.base_url = options.base_url if options.base_url
      end
    end

    initializer "euromailing.extensions" do
      ActiveSupport.on_load(:action_mailer) do
        ActionMailer::Base.add_delivery_method :euromailing, Euromailing::DeliveryMethod
      end
      ActiveSupport.on_load(:active_record) do
        require "euromailing/syncable"
      end
      ActiveSupport.on_load(:active_job) do
        require "euromailing/sync_job"
      end
    end
  end
end
