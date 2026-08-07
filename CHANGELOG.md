# Changelog

## 0.2.0

- Sending-domain management for partner integrations (one account, many
  customer domains, one key with the `transactional:send_any_domain`
  scope): `create_sending_domain`, `sending_domain`,
  `verify_sending_domain`, `delete_sending_domain`, `sending_domains`.
  Euromailing returns ready-made DNS records (DKIM CNAME, SPF include
  token, DMARC) and is the source of truth for verification — poll,
  don't check DNS yourself.

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
