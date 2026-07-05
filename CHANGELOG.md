# Changelog

## 0.1.0

Initial release.

- ActionMailer delivery method (`:euromailing`) for the transactional API
- `Euromailing::Client`: transactional send, contact upsert/delete,
  list subscribe/unsubscribe
- `Euromailing::Syncable`: mirror ActiveRecord models as Euromailing
  contacts via background jobs
- ActionMailbox inbound setup (relay ingress, fed by Euromailing's
  "Deliver to your app" workflow action)
