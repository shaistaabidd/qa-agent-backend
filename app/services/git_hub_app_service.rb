require 'base64'

# Wraps GitHub App authentication (JWT -> installation access token) and the
# handful of Contents API calls the codebase scan needs. Works identically
# for public and private repos — visibility is irrelevant, only the
# installation's granted access matters.
class GitHubAppService
  class ConfigurationError < StandardError; end

  # Installation tokens are valid for an hour; minting one costs a GitHub
  # round trip (~1s). They're cached per process and replaced shortly before
  # they expire, so callers never use an expired one.
  TOKEN_CACHE = Concurrent::Map.new
  TOKEN_REFRESH_MARGIN = 5.minutes

  # The repo list feeds the project page's picker on every load; it only
  # changes when someone edits the installation on GitHub, and linking an
  # installation clears it, so a short cache is safe.
  REPOSITORIES_CACHE = Concurrent::Map.new
  REPOSITORIES_TTL = 60.seconds

  def self.reset_token_cache!
    TOKEN_CACHE.clear
    REPOSITORIES_CACHE.clear
  end

  def self.forget_repositories(installation_id)
    REPOSITORIES_CACHE.delete(installation_id.to_s)
  end

  def self.for_installation(installation_id)
    new(installation_id)
  end

  # GitHub's own install screen: the user picks the account/org and which
  # repos to grant, then GitHub redirects back to the app's callback URL with
  # installation_id (+ an OAuth code, see GitHubUserAuthorization) and state.
  def self.install_url(state)
    slug = ENV.fetch('GITHUB_APP_SLUG', nil).presence || raise(ConfigurationError, 'GITHUB_APP_SLUG is not configured')
    "https://github.com/apps/#{slug}/installations/new?state=#{CGI.escape(state)}"
  end

  def initialize(installation_id)
    @installation_id = installation_id
  end

  def file_content(repo_full_name, path)
    entry = with_token_retry { client.contents(repo_full_name, path: path) }
    return nil unless entry.respond_to?(:content)

    Base64.decode64(entry.content)
  rescue Octokit::NotFound
    nil
  end

  def directory_entries(repo_full_name, path: '')
    entries = with_token_retry { client.contents(repo_full_name, path: path) }
    Array(entries)
  rescue Octokit::NotFound
    []
  end

  # Full names ("owner/name") of every repo the installation was granted.
  def repository_names
    cached = REPOSITORIES_CACHE[cache_key]
    return cached[:names] if cached && cached[:at] > REPOSITORIES_TTL.ago

    names = with_token_retry { client.list_app_installation_repositories(per_page: 100) }[:repositories]
            .map { |repo| repo[:full_name] }.sort
    REPOSITORIES_CACHE[cache_key] = { names: names, at: Time.current }
    names
  end

  private

  attr_reader :installation_id

  def client
    @client ||= Octokit::Client.new(bearer_token: installation_access_token, auto_paginate: true)
  end

  def installation_access_token
    cached = TOKEN_CACHE[cache_key]
    return cached[:token] if cached && cached[:expires_at] > TOKEN_REFRESH_MARGIN.from_now

    response = app_client.create_app_installation_access_token(installation_id)
    expires_at = response[:expires_at]
    expires_at = Time.zone.parse(expires_at) if expires_at.is_a?(String)
    TOKEN_CACHE[cache_key] = { token: response[:token], expires_at: expires_at || 50.minutes.from_now }
    response[:token]
  end

  # A cached token can still be rejected early (permissions changed, app
  # reinstalled). Drop it, mint a fresh one and retry once.
  def with_token_retry
    yield
  rescue Octokit::Unauthorized
    raise if @retried

    @retried = true
    TOKEN_CACHE.delete(cache_key)
    @client = nil
    retry
  end

  def cache_key
    installation_id.to_s
  end

  def app_client
    Octokit::Client.new(bearer_token: app_jwt)
  end

  def app_jwt
    payload = { iat: Time.now.to_i - 60, exp: Time.now.to_i + 540, iss: app_id }
    JWT.encode(payload, private_key, 'RS256')
  end

  def app_id
    ENV.fetch('GITHUB_APP_ID', nil).presence || raise(ConfigurationError, 'GITHUB_APP_ID is not configured')
  end

  def private_key
    raw = ENV.fetch('GITHUB_APP_PRIVATE_KEY',
                    nil).presence || raise(ConfigurationError, 'GITHUB_APP_PRIVATE_KEY is not configured')
    OpenSSL::PKey::RSA.new(raw.gsub('\n', "\n"))
  end
end
