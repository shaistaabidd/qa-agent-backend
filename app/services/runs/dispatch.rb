module Runs
  # Queues a run of one approved scope feature as one of the project's roles.
  class Dispatch < ApplicationService
    def initialize(scope_feature:, role_name:)
      @scope_feature = scope_feature
      @role_name = role_name
    end

    def call
      return failure(:scope_feature_not_approved) unless @scope_feature.approved?
      return failure(:credential_missing) unless credential_configured?

      run = @scope_feature.runs.build(project: @scope_feature.project, role_name: @role_name)
      return failure(:validation_failed, record: run) unless run.save

      RunDispatchJob.perform_later(run.id)
      success(run)
    end

    private

    def credential_configured?
      @scope_feature.project.role_credentials.exists?(role_name: @role_name)
    end
  end
end
