module Runs
  class Dispatch < BaseInteractor
    delegate :scope_feature, to: :context

    def call
      ensure_approved!
      ensure_credential_configured!
      create_run!
      RunDispatchJob.perform_later(context.run.id)
    rescue ActiveRecord::RecordInvalid => e
      context.fail!(error: e.record.errors.full_messages.to_sentence)
    end

    private

    def ensure_approved!
      context.fail!(error: 'Scope feature is not approved yet') unless scope_feature.approved?
    end

    def ensure_credential_configured!
      return if credential_configured?

      context.fail!(error: "No credential configured for role '#{context.role_name}'")
    end

    def credential_configured?
      scope_feature.project.role_credentials.exists?(role_name: context.role_name)
    end

    def create_run!
      context.run = scope_feature.runs.create!(project: scope_feature.project, role_name: context.role_name)
    end
  end
end
