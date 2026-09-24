module ScopeFeatures
  class Approve < BaseInteractor
    delegate :scope_feature, to: :context

    def call
      scope_feature.update!(approved: true)
    rescue ActiveRecord::RecordInvalid => e
      context.fail!(error: e.record.errors.full_messages.to_sentence)
    end
  end
end
