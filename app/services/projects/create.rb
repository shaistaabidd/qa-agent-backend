module Projects
  # Creates a project and makes its creator the project admin.
  class Create < ApplicationService
    def initialize(user:, name:, target_url:)
      @user = user
      @name = name
      @target_url = target_url
    end

    def call
      project = Project.new(name: @name, target_url: @target_url)
      saved = Project.transaction { project.save && project.memberships.create!(user: @user, role: :admin) }

      saved ? success(project) : failure(:validation_failed, record: project)
    end
  end
end
