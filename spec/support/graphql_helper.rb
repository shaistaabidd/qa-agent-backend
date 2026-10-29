module GraphqlHelper
  # Runs the real schema end to end. Pass `as:` (a user) or `session:` to execute
  # as a signed-in caller; nothing about authentication is stubbed.
  def execute_graphql(query, variables: {}, as: nil, session: nil)
    session ||= create(:session, user: as) if as
    QaAgentBackendSchema.execute(
      query,
      variables:,
      context: { current_session: session, current_user: session&.user, ip_address: "127.0.0.1" }
    ).to_h
  end

  def error_codes(result) = result.fetch("errors", []).map { it.dig("extensions", "code") }

  # The same object the multipart middleware hands to the schema.
  def graphql_upload(fixture_name, content_type)
    tempfile = Rack::Test::UploadedFile.new(file_fixture(fixture_name), content_type).tempfile
    file = ActionDispatch::Http::UploadedFile.new(tempfile:, filename: fixture_name, type: content_type)
    ApolloUploadServer::Wrappers::UploadedFile.new(file)
  end
end

RSpec.configure do |config|
  config.include GraphqlHelper, type: :graphql
end
