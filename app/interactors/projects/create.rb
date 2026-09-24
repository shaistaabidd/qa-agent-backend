module Projects
  class Create < BaseInteractor
    def call
      ActiveRecord::Base.transaction do
        create_project
        make_creator_admin
      end
    rescue ActiveRecord::RecordInvalid => e
      context.fail!(error: e.record.errors.full_messages.to_sentence)
    end

    private

    def create_project
      context.project = Project.create!(name: context.name, target_url: context.target_url)
    end

    def make_creator_admin
      context.project.memberships.create!(user: current_user, role: :admin)
    end
  end
end
