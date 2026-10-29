class QaAgentBackendSchema < GraphQL::Schema
  query Types::QueryType
  mutation Types::MutationType

  use GraphQL::Dataloader
  use GraphQL::Schema::Timeout, max_seconds: 10

  max_depth 12
  max_complexity 300
  max_query_string_tokens 5_000
  validate_max_errors 25
  default_max_page_size 100

  disable_introspection_entry_points unless ENV.fetch("GRAPHQL_INTROSPECTION", Rails.env.local?.to_s) == "true"

  rescue_from(ActiveRecord::RecordNotFound) { raise GraphqlErrors.not_found }
  rescue_from(ActionPolicy::Unauthorized) { raise GraphqlErrors.forbidden }
  rescue_from(ActiveRecord::RecordInvalid) do |error|
    raise GraphqlErrors.build(error.record.errors.full_messages.to_sentence, :validation_failed)
  end

  # Unexpected failures never leak their message; the real error goes to the error tracker.
  rescue_from(StandardError) do |error|
    raise error if Rails.env.local?

    Rails.error.report(error, handled: true)
    raise GraphqlErrors.internal
  end
end
