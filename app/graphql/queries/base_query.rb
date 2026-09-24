module Queries
  class BaseQuery < GraphQL::Schema::Resolver
    include ExecutionErrorResponder
  end
end
