module GoogleOauth
  # Google's OAuth 2.0 / OpenID Connect endpoints for "Sign in with Google": the
  # authorization URL the browser is sent to, and the server-side exchange of the
  # code Google returns for the person's profile. Uses PKCE on top of the client
  # secret, so a stolen code is useless without the verifier we kept. One
  # instance serves one sign-in: it keeps that sign-in's access token for the
  # follow-up People API call.
  class Client
    AUTHORIZE_URL = "https://accounts.google.com/o/oauth2/v2/auth".freeze
    TOKEN_URL = URI("https://oauth2.googleapis.com/token").freeze
    USERINFO_URL = URI("https://openidconnect.googleapis.com/v1/userinfo").freeze
    PEOPLE_URL = URI("https://people.googleapis.com/v1/people/me?personFields=phoneNumbers,birthdays").freeze
    SCOPES = %w[openid email profile].freeze
    # Phone and birthday come from the People API. Google calls these scopes
    # sensitive: real users see them only once the app passes Google's review.
    PEOPLE_SCOPES = %w[
      https://www.googleapis.com/auth/user.phonenumbers.read
      https://www.googleapis.com/auth/user.birthday.read
    ].freeze
    # Profile photos are served from Google's own image hosts (lh3.googleusercontent.com, ...).
    PICTURE_HOST = /\A[a-z0-9-]+\.googleusercontent\.com\z/
    HTTP_OPTIONS = { use_ssl: true, open_timeout: 10, read_timeout: 10 }.freeze

    def initialize(config = Rails.configuration.x.google_oauth)
      @config = config
    end

    def configured? = @config[:client_id].present? && @config[:client_secret].present?

    def authorize_url(state:, code_challenge:)
      query = { client_id: @config[:client_id], redirect_uri: @config[:redirect_uri], response_type: "code",
                scope: scopes.join(" "), state:, code_challenge:, code_challenge_method: "S256",
                prompt: "select_account" }
      "#{AUTHORIZE_URL}?#{query.to_query}"
    end

    def profile_for(code:, code_verifier:)
      tokens = post_form(TOKEN_URL, code:, code_verifier:, grant_type: "authorization_code",
                                    client_id: @config[:client_id], client_secret: @config[:client_secret],
                                    redirect_uri: @config[:redirect_uri])
      @access_token = tokens.fetch("access_token")
      Profile.from_userinfo(get_json(USERINFO_URL, access_token: @access_token))
    end

    # Phone and birthday for the person who just signed in, when the People API
    # is switched on (config people_details). They are extras: Google refusing
    # (API disabled, permission unticked) leaves them out.
    def people_details
      return {} unless @config[:people_details] && @access_token

      Profile.people_details(get_json(PEOPLE_URL, access_token: @access_token))
    rescue Error => e
      Rails.logger.warn("Google sign-in: People API refused (#{e.message}); is it enabled for the project?")
      {}
    end

    # The HTTP response holding a profile photo. Only Google's image hosts are
    # fetched, so the API can't be pointed at an internal address.
    def picture(url)
      uri = URI(url)
      raise Error, "Not a Google photo URL" unless uri.is_a?(URI::HTTPS) && uri.host.to_s.match?(PICTURE_HOST)

      response = perform(uri, Net::HTTP::Get.new(uri))
      raise Error, "Photo too large" if response.body.bytesize > User::IMAGE_MAX_SIZE

      response
    end

    private

    def scopes = @config[:people_details] ? SCOPES + PEOPLE_SCOPES : SCOPES

    def post_form(uri, **form)
      request = Net::HTTP::Post.new(uri)
      request.set_form_data(form)
      json(perform(uri, request))
    end

    def get_json(uri, access_token:)
      request = Net::HTTP::Get.new(uri)
      request["Authorization"] = "Bearer #{access_token}"
      json(perform(uri, request))
    end

    def json(response)
      JSON.parse(response.body)
    rescue JSON::ParserError
      raise Error, "Unreadable answer from Google"
    end

    # Any refusal, outage or unreadable answer ends this sign-in attempt; the
    # person starts again. Google's error text is not passed on: it can echo the code.
    def perform(uri, request)
      response = Net::HTTP.start(uri.host, uri.port, **HTTP_OPTIONS) { |http| http.request(request) }
      raise Error, "Google answered #{response.code}" unless response.is_a?(Net::HTTPSuccess)

      response
    rescue Timeout::Error, SystemCallError, SocketError, OpenSSL::SSL::SSLError => e
      raise Error, e.class.name
    end
  end
end
