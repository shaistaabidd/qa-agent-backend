# Google's token and userinfo endpoints, answered by WebMock so no spec reaches
# Google, and the browser's trip through Sign in with Google.
module GoogleOauthHelper
  GOOGLE_NONCE = "browser-nonce".freeze

  def google_userinfo(**overrides)
    { sub: "google-uid-1", email: "ada@example.com", email_verified: true,
      given_name: "Ada", family_name: "Lovelace" }.merge(overrides)
  end

  # A People API person with a primary phone and a full birthday.
  def google_person(phone: "+12015550123", birthday: { year: 1990, month: 4, day: 15 })
    { phoneNumbers: [{ metadata: { primary: true }, value: "(201) 555-0123", canonicalForm: phone }],
      birthdays: [{ metadata: { primary: true }, date: birthday }] }
  end

  def stub_google_people(status: 200, person: {})
    stub_request(:get, GoogleOauth::Client::PEOPLE_URL.to_s)
      .with(headers: { "Authorization" => "Bearer ya29.test-token" })
      .to_return(status:, body: person.to_json, headers: { "Content-Type" => "application/json" })
  end

  def stub_google_profile(token_status: 200, **userinfo)
    stub_request(:post, GoogleOauth::Client::TOKEN_URL.to_s)
      .to_return(status: token_status, body: { access_token: "ya29.test-token", token_type: "Bearer" }.to_json,
                 headers: { "Content-Type" => "application/json" })
    stub_request(:get, GoogleOauth::Client::USERINFO_URL.to_s)
      .with(headers: { "Authorization" => "Bearer ya29.test-token" })
      .to_return(body: google_userinfo(**userinfo).to_json, headers: { "Content-Type" => "application/json" })
    stub_google_people
  end

  # Start, then Google's callback, as the API's two endpoints run them; returns
  # the one-time code the frontend receives in its callback URL's fragment.
  def google_handoff_code(nonce: GOOGLE_NONCE, code: "google-auth-code", error: nil)
    google_url = Auth::StartGoogleSignIn.call(nonce:).value
    state = query_param(google_url, "state")
    frontend_url = Auth::CompleteGoogleSignIn.call(state:, code:, error:).value
    fragment_param(frontend_url, "code")
  end

  def query_param(url, name) = Rack::Utils.parse_query(URI(url).query)[name]
  def fragment_param(url, name) = Rack::Utils.parse_query(URI(url).fragment)[name]

  def sign_in_with_google_mutation
    <<~GQL
      mutation($code: String!, $nonce: String!) {
        signInWithGoogle(input: { code: $code, nonce: $nonce }) { message token user { id email role } }
      }
    GQL
  end
end

RSpec.configure do |config|
  config.include GoogleOauthHelper
end
