max_threads_count = ENV.fetch("RAILS_MAX_THREADS", 5)
min_threads_count = ENV.fetch("RAILS_MIN_THREADS") { max_threads_count }
threads min_threads_count, max_threads_count

worker_timeout 3600 if ENV.fetch("RAILS_ENV", "development") == "development"

port ENV.fetch("PORT", 3000)

# Rejects oversized bodies with 413 before they are read; profile images are capped at 5 MB.
http_content_length_limit 10 * 1024 * 1024

environment ENV.fetch("RAILS_ENV", "development")

workers ENV.fetch("WEB_CONCURRENCY", 0)
preload_app! if ENV.fetch("WEB_CONCURRENCY", 0).to_i.positive?

pidfile ENV["PIDFILE"] if ENV["PIDFILE"]

plugin :tmp_restart
