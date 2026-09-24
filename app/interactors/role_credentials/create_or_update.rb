module RoleCredentials
  class CreateOrUpdate < BaseInteractor
    delegate :project, to: :context

    def call
      context.role_credential = upsert_credential!
    rescue ActiveRecord::RecordInvalid => e
      context.fail!(error: e.record.errors.full_messages.to_sentence)
    end

    private

    def upsert_credential!
      credential = project.role_credentials.find_or_initialize_by(role_name: context.role_name)
      credential.encrypted_credential_ref = context.credential_value
      credential.save!
      credential
    end
  end
end
