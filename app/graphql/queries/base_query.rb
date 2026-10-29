module Queries
  class BaseQuery < GraphQL::Schema::Resolver
    include GraphqlOperation

    argument_class Types::BaseArgument
  end
end
