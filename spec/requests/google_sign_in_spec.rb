require "rails_helper"

# The two endpoints the browser visits; what they decide is covered in
# spec/graphql/mutations/auth/sign_in_with_google_spec.rb.
RSpec.describe "Sign in with Google endpoints" do
  it "sends the browser to Google with the client ID, scope, state and PKCE challenge" do
    get "/auth/google", params: { nonce: "browser-nonce" }

    expect(response).to have_http_status(:found)
    expect(response.location).to start_with(GoogleOauth::Client::AUTHORIZE_URL)
    expect(Rack::Utils.parse_query(URI(response.location).query)).to include(
      "client_id" => "test-client-id.apps.googleusercontent.com",
      "redirect_uri" => "http://api.example.test/auth/google/callback",
      "response_type" => "code", "code_challenge_method" => "S256",
      "scope" => "openid email profile https://www.googleapis.com/auth/user.phonenumbers.read " \
                 "https://www.googleapis.com/auth/user.birthday.read",
      "state" => be_present, "code_challenge" => be_present
    )
    expect(response.location).not_to include("browser-nonce", "test-client-secret")
  end

  it "asks for name, email and photo only while the People API is switched off" do
    allow(Rails.configuration.x).to receive(:google_oauth)
      .and_return(Rails.configuration.x.google_oauth.merge(people_details: false))

    get "/auth/google", params: { nonce: "browser-nonce" }

    expect(query_param(response.location, "scope")).to eq("openid email profile")
  end

  it "sends the browser back to the frontend with a one-time code after Google's callback" do
    stub_google_profile
    get "/auth/google", params: { nonce: "browser-nonce" }

    get "/auth/google/callback", params: { state: query_param(response.location, "state"), code: "google-auth-code" }

    expect(response).to have_http_status(:found)
    expect(response.location).to start_with("#{Rails.configuration.x.frontend_url}/auth/google/callback#code=")
    expect(URI(response.location).query).to be_nil
  end

  it "sends the browser back to the frontend when the sign-in can't start" do
    get "/auth/google"

    expect(response.location).to start_with("#{Rails.configuration.x.frontend_url}/auth/google/callback#code=")
  end

  it "keeps Google's code, the state and the nonce out of the logs" do
    filter = ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters)

    expect(filter.filter("code" => "c", "state" => "s", "nonce" => "n", "error" => "access_denied"))
      .to eq("code" => "[FILTERED]", "state" => "[FILTERED]", "nonce" => "[FILTERED]", "error" => "access_denied")
  end
end
