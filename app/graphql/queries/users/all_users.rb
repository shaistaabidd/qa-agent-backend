module Queries
  module Users
    class AllUsers < BaseQuery
      include Paginatable

      description "Super admins only: a filtered, paginated list of users, newest first"

      type Types::UserPaginationType, null: false

      argument :filters, Types::UserFilterInput, required: false, description: "Filters and paging"

      extras [:lookahead]

      def resolve(lookahead:, filters: nil)
        authorize! User, to: :index?

        options = filters.to_h
        users = ::Users::FilterQuery.new(authorized_scope(User.all)).call(**filters_without_paging(options))
        users = users.includes(image_attachment: :blob) if lookahead.selection(:all_data).selects?(:image_url)
        paginate_with_filter(users, options)
      end
    end
  end
end
