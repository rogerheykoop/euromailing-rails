# euromailing-rails

Rails integration for [Euromailing](https://euromailing.com): transactional
mail through ActionMailer, contact/list management, automatic user sync,
and inbound mail via ActionMailbox.

## Installation

```ruby
# Gemfile
gem "euromailing-rails"
```

```ruby
# config/initializers/euromailing.rb  (or via config.euromailing in application.rb)
Rails.application.config.euromailing.api_key =
  Rails.application.credentials.dig(:euromailing, :api_key)
```

Create the API key under **Account → API keys** in Euromailing. For
transactional sending it needs the `transactional:send` scope and must be
**bound to your sending domain**; for list/contact sync add
`contacts:write` and `lists:write`.

## 1. Transactional mail (ActionMailer)

```ruby
# config/environments/production.rb
config.action_mailer.delivery_method = :euromailing
```

Existing mailers work unchanged — the From address must be on the API
key's bound domain:

```ruby
class PasswordMailer < ApplicationMailer
  default from: "MyApp <noreply@yourdomain.example>"

  def reset(user)
    mail to: user.email, subject: "Reset your password"
  end
end
```

One recipient per message; prefer `deliver_later` (the API allows 60
requests/minute per key, and ActiveJob retries give you backoff).
Transactional mail carries no unsubscribe headers, and recipients who
unsubscribed from marketing still receive it; only GDPR-erased addresses
are refused (`Euromailing::ApiError` with code `recipient_suppressed`).

## 2. Lists & contacts

```ruby
client = Euromailing.client

client.upsert_contact(email: "jan@example.com", first_name: "Jan",
                      custom_fields: { plan: "pro" })
client.delete_contact(email: "jan@example.com")

client.subscribe(list_id: "LIST-UUID", email: "jan@example.com")
client.unsubscribe(list_id: "LIST-UUID", email: "jan@example.com")
client.lists  # => [{ "id" => …, "name" => … }, …]
```

All methods raise `Euromailing::ApiError` (with `#status` and `#code`)
on failure.

## 3. User sync

Mirror your users as Euromailing contacts — creates/updates upsert,
destroys delete, all in background jobs:

```ruby
class User < ApplicationRecord
  include Euromailing::Syncable
  euromailing_sync lists: ["NEWSLETTER-LIST-UUID"], if: ->(u) { u.newsletter? }

  def euromailing_contact_attributes
    { email: email, first_name: first_name, last_name: last_name,
      custom_fields: { plan: plan } }
  end
end
```

`Euromailing::SyncJob` retries on API errors (5 attempts, polynomial
backoff) and treats a 404 on delete as success.

## 4. Inbound mail (ActionMailbox)

Euromailing pushes the raw mail to your app's standard ActionMailbox
relay ingress — no custom webhook code, just Rails:

1. In your app: `bin/rails action_mailbox:install`, then

   ```ruby
   # config/environments/production.rb
   config.action_mailbox.ingress = :relay
   ```

   and set the ingress password:

   ```
   bin/rails credentials:edit
   # action_mailbox:
   #   ingress_password: <generate something long>
   ```

2. In Euromailing: create a workflow with an **inbound message** trigger
   on your inbound domain and add the **"Deliver to your app
   (ActionMailbox)"** action. Configure:
   - URL: `https://your-app.example/rails/action_mailbox/relay/inbound_emails`
   - Ingress password: the value from step 1 (stored encrypted).

3. Route in your app like any other ActionMailbox source:

   ```ruby
   class ApplicationMailbox < ActionMailbox::Base
     routing(/^support@/i => :support)
   end

   class SupportMailbox < ApplicationMailbox
     def process
       Ticket.create!(from: mail.from.first, subject: mail.subject,
                      body: mail.text_part&.decoded)
     end
   end
   ```

Because the workflow engine drives the push, you can filter, branch or
tag in Euromailing *before* mail reaches your app, and delivery retries
automatically when your app is briefly down (5xx).

## Without Rails

The client is plain Ruby — configure and use it directly:

```ruby
Euromailing.configure { |c| c.api_key = ENV["EUROMAILING_API_KEY"] }
Euromailing.client.deliver_transactional(from: "…", to: "…", subject: "…", text_body: "…")
```

## Development

```
bundle install
bundle exec rspec
```
