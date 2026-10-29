module RoleCredentials
  class CreateOrUpdate < ApplicationService
    def initialize(project:, role_name:, credential_value:)
      @project = project
      @role_name = role_name
      @credential_value = credential_value
    end

    def call
      credential = @project.role_credentials.find_or_initialize_by(role_name: @role_name)
      credential.encrypted_credential_ref = @credential_value
      return failure(:validation_failed, record: credential) unless credential.save

      success(credential)
    end
  end
end
