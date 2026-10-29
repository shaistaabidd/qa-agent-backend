module Sms
  # The provider or network failed in a way worth retrying (5xx, rate limit, timeout).
  class TransientError < StandardError; end
end
