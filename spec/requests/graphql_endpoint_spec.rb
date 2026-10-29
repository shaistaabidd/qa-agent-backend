require "rails_helper"

RSpec.describe "POST /graphql" do
  let(:allowed_origin) { Rails.configuration.x.cors_allowed_origins.first }
  let(:me_query) { { query: "{ fetchUser { id } }" } }

  def post_graphql(body, headers: {})
    post "/graphql", params: body.to_json, headers: { "Content-Type" => "application/json", **headers }
  end

  def json = response.parsed_body

  describe "authentication" do
    let(:session) { create(:session) }

    it "accepts a bearer token" do
      post_graphql(me_query, headers: { "Authorization" => "Bearer #{session.token}" })

      expect(json.dig("data", "fetchUser", "id")).to eq(session.user_id.to_s)
    end

    it "treats an unknown token as signed out" do
      post_graphql(me_query, headers: { "Authorization" => "Bearer not-a-real-token" })

      expect(json.dig("errors", 0, "extensions", "code")).to eq("UNAUTHENTICATED")
    end

    it "treats a revoked user's token as signed out" do
      session.user.update!(access_revoked_at: Time.current)

      post_graphql(me_query, headers: { "Authorization" => "Bearer #{session.token}" })

      expect(json.dig("errors", 0, "extensions", "code")).to eq("UNAUTHENTICATED")
    end
  end

  describe "CORS" do
    it "allows the configured frontend origin" do
      options "/graphql", headers: { "Origin" => allowed_origin, "Access-Control-Request-Method" => "POST",
                                     "Access-Control-Request-Headers" => "authorization, content-type" }

      expect(response.headers["Access-Control-Allow-Origin"]).to eq(allowed_origin)
    end

    it "does not allow any other origin" do
      options "/graphql", headers: { "Origin" => "https://evil.example", "Access-Control-Request-Method" => "POST" }

      expect(response.headers["Access-Control-Allow-Origin"]).to be_nil
    end
  end

  it "answers malformed variables with 400" do
    post "/graphql", params: { query: "{ fetchUser { id } }", variables: "{not json" }

    expect(response).to have_http_status(:bad_request)
    expect(json.dig("errors", 0, "extensions", "code")).to eq("BAD_REQUEST")
  end

  it "accepts a multipart file upload" do
    session = create(:session)
    operations = {
      query: "mutation($image: Upload) { updateUser(input: { userAttributes: { image: $image } }) { user { id } } }",
      variables: { image: nil }
    }

    post "/graphql", params: {
      operations: operations.to_json,
      map: { "0" => ["variables.image"] }.to_json,
      "0" => Rack::Test::UploadedFile.new(file_fixture("avatar.png"), "image/png")
    }, headers: { "Authorization" => "Bearer #{session.token}" }

    expect(json["errors"]).to be_nil
    expect(session.user.reload.image).to be_attached
  end
end
