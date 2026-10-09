require 'rails_helper'

RSpec.describe GitHubUserAuthorization do
  let(:oauth_client) { instance_double(Octokit::Client) }
  let(:user_client) { instance_double(Octokit::Client) }

  before do
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with('GITHUB_APP_CLIENT_ID', nil).and_return('client-id')
    allow(ENV).to receive(:fetch).with('GITHUB_APP_CLIENT_SECRET', nil).and_return('client-secret')
    allow(Octokit::Client).to receive(:new).and_return(oauth_client, user_client)
  end

  it "checks the installation against the user's own installations" do
    allow(oauth_client).to receive(:exchange_code_for_token)
      .with('code', 'client-id', 'client-secret').and_return(access_token: 'user-token')
    allow(user_client).to receive(:list_user_installations)
      .and_return(installations: [{ id: 777, account: { login: 'me', type: 'User' } }])

    authorization = described_class.new('code')

    expect(authorization.can_access_installation?('777')).to be true
  end

  it "returns false for someone else's installation" do
    allow(oauth_client).to receive(:exchange_code_for_token).and_return(access_token: 'user-token')
    allow(user_client).to receive(:list_user_installations)
      .and_return(installations: [{ id: 777, account: { login: 'me', type: 'User' } }])

    expect(described_class.new('code').can_access_installation?('999')).to be false
  end

  it 'lists installations with their account' do
    allow(oauth_client).to receive(:exchange_code_for_token).and_return(access_token: 'user-token')
    allow(user_client).to receive(:list_user_installations)
      .and_return(installations: [{ id: 777, account: { login: 'Staunchglobal', type: 'Organization' } }])

    expect(described_class.new('code').installations).to eq(
      [{ id: 777, account_login: 'Staunchglobal', account_type: 'Organization' }]
    )
  end

  it 'builds a sign-in URL with the client id and state' do
    expect(described_class.authorize_url('abc')).to eq(
      'https://github.com/login/oauth/authorize?client_id=client-id&state=abc'
    )
  end

  it 'raises when GitHub rejects the code' do
    allow(oauth_client).to receive(:exchange_code_for_token).and_return(error: 'bad_verification_code')

    expect { described_class.new('code').can_access_installation?('777') }
      .to raise_error(GitHubUserAuthorization::AuthorizationError)
  end
end
