# Changelog

## 0.1.1

- Inline (CID) images: `attachments.inline[...]` in ActionMailer now
  pass their `content_id` to the API, so `<img src="cid:...">`
  references resolve in the delivered mail.
- `deliver!` calls `mail.ready_to_send!` so content-ids exist even when
  the delivery method is invoked directly.

## 0.1.0

Initial release.

- ActionMailer delivery method (`:euromailing`) for the transactional API
- `Euromailing::Client`: transactional send, contact upsert/delete,
  list subscribe/unsubscribe
- `Euromailing::Syncable`: mirror ActiveRecord models as Euromailing
  contacts via background jobs
- ActionMailbox inbound setup (relay ingress, fed by Euromailing's
  "Deliver to your app" workflow action)
