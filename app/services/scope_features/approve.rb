module ScopeFeatures
  class Approve < ApplicationService
    def initialize(scope_feature:)
      @scope_feature = scope_feature
    end

    def call
      return failure(:validation_failed, record: @scope_feature) unless @scope_feature.update(approved: true)

      success(@scope_feature)
    end
  end
end
