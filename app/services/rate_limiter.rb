# Fixed-window counter in the shared cache. The discriminator is hashed so
# emails never appear in cache keys, and case-folded so "Jane@x.com" and
# "jane@x.com " share one budget instead of multiplying the limit.
class RateLimiter
  def initialize(scope:, discriminator:, limit:, period:)
    @key = "rate_limit:#{scope}:#{OpenSSL::Digest::SHA256.hexdigest(discriminator.to_s.strip.downcase)}"
    @limit = limit
    @period = period
  end

  def exceeded?
    Rails.cache.increment(@key, 1, expires_in: @period).to_i > @limit
  end
end
