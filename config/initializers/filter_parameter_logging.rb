# Keeps credentials and personal data out of logs and error reports.
# GraphQL variable names are chosen by the client and secrets can be inlined in
# the query string, so the whole query, variables and multipart operations are
# filtered; logs keep operationName for tracing. EmailLog bodies hold live
# sign-in codes, so `body` and `recipient` are hidden wherever a record is
# inspected (console, error reports) or its SQL binds are logged. A user's
# search_document repeats their email and names, so it is hidden with them.
Rails.application.config.filter_parameters += %i[
  query variables operations
  passw email secret token _key crypt salt certificate otp
  first_name last_name full_name phone google_uid search_document
  recipient body
  credential
]
# Sign in with Google's callback and handoff values (an OAuth code, its state, the nonce).
Rails.application.config.filter_parameters += [/\Acode\z/, /\Astate\z/, /\Anonce\z/]
# The one-time Google handoff code rides in this redirect's fragment, which parameter filtering doesn't cover.
Rails.application.config.filter_redirect << %r{/auth/google/callback}
