release: bin/rails db:migrate && bin/rails feature_flags:register
web: bundle exec puma -C config/puma.rb
worker: bundle exec sidekiq -C config/sidekiq.yml
