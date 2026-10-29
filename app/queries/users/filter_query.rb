module Users
  # Narrows an already-authorized user scope by the admin list filters.
  class FilterQuery
    include ListFilters

    ACCESS_STATUSES = %w[active inactive].freeze

    def initialize(scope)
      @scope = scope
    end

    def call(role: nil, search: nil, status: nil, pending: nil, archived: nil)
      relation = @scope.order(created_at: :desc, id: :desc)
      relation = relation.where(role:) if role
      relation = filter_by_archived(relation, archived)
      relation = filter_by_invitation(relation, pending)
      relation = filter_by_access(relation, status)
      filter_by_search(relation, search)
    end

    private

    def filter_by_archived(relation, archived)
      return relation if archived.nil?

      archived ? relation.archived : relation.not_archived
    end

    def filter_by_invitation(relation, pending)
      return relation if pending.nil?

      pending ? relation.invitation_pending : relation.joined
    end

    def filter_by_access(relation, status)
      case status
      when "active" then relation.with_access
      when "inactive" then relation.access_revoked
      else relation
      end
    end
  end
end
