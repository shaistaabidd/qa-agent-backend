module FeatureFlag
  # Wraps Flipper's storage to log every flag change (dashboard, console or
  # code): which flag, what happened and to which gate, with the log's own
  # timestamp. It can't say who: the dashboard uses one shared login.
  class ChangeLogAdapter < Flipper::Adapters::Wrapper
    CHANGES = %i[enable disable clear remove].freeze

    def wrap(method, *, **kwargs, &)
      result = super
      log_change(method, *) if CHANGES.include?(method)
      result
    end

    private

    def log_change(method, feature, gate = nil, thing = nil)
      target = gate ? "#{gate.key}=#{thing.value}" : "every gate"
      Rails.logger.info("[feature flag] #{method} #{feature.key} (#{target})")
    end
  end
end
