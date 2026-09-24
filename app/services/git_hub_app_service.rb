require 'base64'

# Wraps GitHub App authentication (JWT -> installation access token) and the
# handful of Contents API calls the codebase scan needs. Works identically
# for public and private repos — visibility is irrelevant, only the
# installation's granted access matters.
class GitHubAppService
  class ConfigurationError < StandardError; end

  def self.for_installation(installation_id)
    new(installation_id)
  end

  def initialize(installation_id)
    @installation_id = installation_id
  end

  def file_content(repo_full_name, path)
    entry = client.contents(repo_full_name, path: path)
    return nil unless entry.respond_to?(:content)

    Base64.decode64(entry.content)
  rescue Octokit::NotFound
    nil
  end

  def directory_entries(repo_full_name, path: '')
    entries = client.contents(repo_full_name, path: path)
    Array(entries)
  rescue Octokit::NotFound
    []
  end

  private

  attr_reader :installation_id

  def client
    @client ||= Octokit::Client.new(bearer_token: installation_access_token)
  end

  def installation_access_token
    app_client.create_app_installation_access_token(installation_id)[:token]
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
