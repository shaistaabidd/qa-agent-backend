# Flags and their checks live in FeatureFlag. Nothing here talks to Redis, so
# booting (and db:migrate) never needs it; `bin/rails feature_flags:register`
# adds flags to the dashboard. Flipper's Rails engine already memoizes and
# preloads flags per request (Flipper::Middleware::Memoizer), so a list of
# users reads them once, not once per row; spec/requests/feature_flag_lookups_spec.rb.
require "flipper/adapters/redis"
require "flipper/adapters/memory"

Flipper.configure do |config|
  config.adapter do
    storage = if Rails.env.test?
                Flipper::Adapters::Memory.new
              else
                Flipper::Adapters::Redis.new(Redis.new(**Rails.configuration.x.redis))
              end
    FeatureFlag::ChangeLogAdapter.new(FeatureFlag::EligibleTargetsAdapter.new(storage))
  end
end

# One group per role (`users`, `super_admins`). Once per boot: Flipper refuses
# to register a group twice, so not on every development reload (to_prepare).
Rails.application.config.after_initialize { FeatureFlag.register_role_groups }
