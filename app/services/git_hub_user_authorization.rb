# Proves which GitHub App installations the person completing the install
# flow can actually access. The installation_id on the callback URL is just a
# query param, so without this check anyone could link another org's
# installation (installation ids are sequential) to their own project and
# scan that org's private code.
#
# The one-time `code` comes either from the install redirect (needs "Request
# user authorization (OAuth) during installation" enabled on the GitHub App)
# or from a plain "Sign in with GitHub" (see .authorize_url).
class GitHubUserAuthorization
  class AuthorizationError < StandardError; end

  # Sign-in only, no install screen: for linking an installation that already
  # exists, e.g. one an org owner set up. GitHub redirects to the App's
  # callback URL with `code` and `state` but no installation_id.
  def self.authorize_url(state)
    "https://github.com/login/oauth/authorize?#{URI.encode_www_form(client_id: client_id, state: state)}"
  end

  def initialize(code)
    @code = code
  end

  def can_access_installation?(installation_id)
    ids = installations.pluck(:id)
    Rails.logger.info("[GitHub] user can access installations #{ids.inspect}; requested #{installation_id}")
    ids.include?(installation_id.to_i)
  end

  # This app's installations the user can see: their own account's, plus any
  # org installation that covers at least one repo they have access to.
  # Memoized because the code behind the token is single-use.
  def installations
    @installations ||= user_client.list_user_installations(per_page: 100)[:installations].map do |installation|
      { id: installation[:id], account_login: installation[:account][:login], account_type: installation[:account][:type] }
    end
  end

  private

  attr_reader :code

  def user_client
    Octokit::Client.new(access_token: user_access_token, auto_paginate: true)
  end

  # GitHub answers a bad/expired/reused code with 200 + { error: ... }, not
  # an HTTP error, so the missing token is the failure signal.
  def user_access_token
    raise AuthorizationError, 'GitHub authorization code is missing' if code.blank?

    response = Octokit::Client.new.exchange_code_for_token(code, client_id, client_secret)
    return response[:access_token] if response[:access_token].present?

    Rails.logger.warn("[GitHub] code exchange failed: #{response[:error]} — #{response[:error_description]}")
    raise AuthorizationError, 'GitHub authorization expired or was already used — please connect again'
  end

  def client_id = self.class.client_id
  def client_secret = self.class.client_secret

  def self.client_id
    ENV.fetch('GITHUB_APP_CLIENT_ID', nil).presence ||
      raise(GitHubAppService::ConfigurationError, 'GITHUB_APP_CLIENT_ID is not configured')
  end

  def self.client_secret
    ENV.fetch('GITHUB_APP_CLIENT_SECRET', nil).presence ||
      raise(GitHubAppService::ConfigurationError, 'GITHUB_APP_CLIENT_SECRET is not configured')
  end
end
