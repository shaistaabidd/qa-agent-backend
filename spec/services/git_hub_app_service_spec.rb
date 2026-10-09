require 'rails_helper'

RSpec.describe GitHubAppService do
  let(:rsa_key) { OpenSSL::PKey::RSA.new(2048) }
  let(:app_client) { instance_double(Octokit::Client) }
  let(:installation_client) { instance_double(Octokit::Client) }
  let(:service) { described_class.for_installation(42) }

  before do
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with('GITHUB_APP_ID', nil).and_return('123')
    allow(ENV).to receive(:fetch).with('GITHUB_APP_PRIVATE_KEY', nil).and_return(rsa_key.to_pem)

    allow(Octokit::Client).to receive(:new).and_return(app_client, installation_client)
    allow(app_client).to receive(:create_app_installation_access_token)
      .with(42).and_return(token: 'installation-token')
  end

  describe '#file_content' do
    it 'decodes base64 file contents' do
      entry = double(content: Base64.encode64('hello world'))
      allow(installation_client).to receive(:contents).with('acme/app', path: 'README.md').and_return(entry)

      expect(service.file_content('acme/app', 'README.md')).to eq('hello world')
    end

    it 'returns nil for a missing file' do
      allow(installation_client).to receive(:contents).and_raise(Octokit::NotFound)

      expect(service.file_content('acme/app', 'missing.rb')).to be_nil
    end
  end

  describe '#directory_entries' do
    it 'returns an empty array for a missing directory' do
      allow(installation_client).to receive(:contents).and_raise(Octokit::NotFound)

      expect(service.directory_entries('acme/app', path: 'nope')).to eq([])
    end
  end

  describe '#repository_names' do
    it "returns the installation's repos as sorted owner/name strings" do
      allow(installation_client).to receive(:list_app_installation_repositories)
        .and_return(repositories: [{ full_name: 'acme/web' }, { full_name: 'acme/api' }])

      expect(service.repository_names).to eq(%w[acme/api acme/web])
    end
  end

  context 'when GITHUB_APP_ID is not configured' do
    before { allow(ENV).to receive(:fetch).with('GITHUB_APP_ID', nil).and_return(nil) }

    it 'raises a configuration error instead of calling GitHub' do
      expect { service.file_content('acme/app', 'README.md') }
        .to raise_error(GitHubAppService::ConfigurationError)
    end
  end
end
