require_relative "lib/euromailing/version"

Gem::Specification.new do |spec|
  spec.name    = "euromailing-rails"
  spec.version = Euromailing::VERSION
  spec.authors = ["Roger Heykoop"]
  spec.email   = ["support@euromailing.com"]

  spec.summary     = "Rails integration for Euromailing: transactional mail, list management, user sync and ActionMailbox inbound."
  spec.description = "ActionMailer delivery method for Euromailing's transactional API, a client for " \
                     "contact/list management, a Syncable concern to mirror your users as contacts, " \
                     "and setup for receiving Euromailing inbound mail through ActionMailbox."
  spec.homepage    = "https://github.com/rogerheykoop/euromailing-rails"
  spec.license     = "MIT"

  spec.metadata = {
    "homepage_uri"          => spec.homepage,
    "source_code_uri"       => spec.homepage,
    "changelog_uri"         => "#{spec.homepage}/blob/main/CHANGELOG.md",
    "rubygems_mfa_required" => "true"
  }

  spec.required_ruby_version = ">= 3.1"

  spec.files = Dir["lib/**/*", "README.md", "LICENSE.txt", "CHANGELOG.md"]
  spec.require_paths = ["lib"]

  # Net::HTTP + JSON only — no runtime dependencies beyond what any Rails
  # app already has. ActiveSupport/ActiveJob are soft dependencies: the
  # Syncable concern and SyncJob load only when they're present.
  spec.add_development_dependency "rspec", "~> 3.13"
  spec.add_development_dependency "webmock", "~> 3.0"
  spec.add_development_dependency "activesupport", ">= 7.0"
  spec.add_development_dependency "activejob", ">= 7.0"
  spec.add_development_dependency "mail", "~> 2.8"
end
