# Signed URLs for the disk service need a host, which a controller supplies in production
# (ActiveStorage::SetCurrent). Specs that build them outside a request get this one.
RSpec.configure do |config|
  config.before { ActiveStorage::Current.url_options = { host: "www.example.com" } }
end
