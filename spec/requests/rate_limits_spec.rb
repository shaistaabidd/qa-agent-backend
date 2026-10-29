require "rails_helper"

# Rack::Attack's edge limit on /graphql (300 a minute per IP), and the agent worker's exemption from it.
RSpec.describe "GraphQL edge rate limit" do
  def post_graphql(headers = {})
    post "/graphql", params: { query: "{ __typename }" }.to_json,
                     headers: { "Content-Type" => "application/json" }.merge(headers)
  end

  def code = response.parsed_body.dig("errors", 0, "extensions", "code")

  before { Rack::Attack.cache.store.clear }

  it "throttles an address after 300 requests in a minute" do
    300.times { post_graphql }
    expect(response).not_to have_http_status(:too_many_requests)

    post_graphql

    expect(response).to have_http_status(:too_many_requests)
    expect(code).to eq("RATE_LIMITED")
  end

  it "does not throttle the agent worker, which calls back many times per run" do
    310.times { post_graphql("X-Agent-Token" => "agent-api-token") }

    expect(response).not_to have_http_status(:too_many_requests)
  end

  it "still throttles a wrong agent token, so the secret can't be guessed at speed" do
    300.times { post_graphql("X-Agent-Token" => "guess") }

    post_graphql("X-Agent-Token" => "guess")

    expect(response).to have_http_status(:too_many_requests)
  end

  it "keeps throttling other addresses separately" do
    300.times { post_graphql }

    post "/graphql", params: { query: "{ __typename }" }.to_json,
                     headers: { "Content-Type" => "application/json" }, env: { "REMOTE_ADDR" => "203.0.113.9" }

    expect(response).not_to have_http_status(:too_many_requests)
  end
end
