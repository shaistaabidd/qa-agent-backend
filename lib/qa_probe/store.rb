module QaProbe
  # Reports live briefly in Redis (shared by Puma workers and Sidekiq), keyed
  # by id for requests and in a capped list for jobs.
  module Store
    REQUEST_TTL = 15 * 60
    MAX_JOBS = 500
    PREFIX = "qa_probe".freeze

    module_function

    def save_request(report)
      redis.set("#{PREFIX}:req:#{report[:id]}", JSON.generate(report), ex: REQUEST_TTL)
    end

    def request(id)
      json = redis.get("#{PREFIX}:req:#{id}")
      json && JSON.parse(json)
    end

    def save_job(report)
      redis.multi do |tx|
        tx.lpush("#{PREFIX}:jobs", JSON.generate(report))
        tx.ltrim("#{PREFIX}:jobs", 0, MAX_JOBS - 1)
      end
    end

    # Job reports that started at or after `since` (a Time), oldest first.
    def jobs_since(since)
      redis.lrange("#{PREFIX}:jobs", 0, MAX_JOBS - 1)
           .map { |json| JSON.parse(json) }
           .select { |report| report["started_at"] && Time.iso8601(report["started_at"]) >= since }
           .reverse
    end

    def redis
      @redis ||= Redis.new(url: ENV["REDISCLOUD_URL"].presence || ENV.fetch("REDIS_URL", "redis://localhost:6379/0"))
    end
  end
end
