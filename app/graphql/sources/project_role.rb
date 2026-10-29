module Sources
  # Batches "what is this user's role in project X" so a project list costs one query, not one per row.
  class ProjectRole < GraphQL::Dataloader::Source
    def initialize(user_id)
      @user_id = user_id
      super()
    end

    def fetch(project_ids)
      roles = Membership.where(user_id: @user_id, project_id: project_ids).pluck(:project_id, :role).to_h
      project_ids.map { roles[it] }
    end
  end
end
