require 'rails_helper'

RSpec.describe AgentWorkerClient do
  let(:project) { create(:project, target_url: 'https://staging.example.com') }
  let(:scope_feature) { create(:scope_feature, project: project, name: 'Checkout', route: '/checkout') }
  let(:run) { create(:run, project: project, scope_feature: scope_feature, role_name: 'admin') }

  before do
    create(:role_credential, project: project, role_name: 'admin')

    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with('AGENT_WORKER_BASE_URL', nil).and_return('https://worker.internal')
    allow(ENV).to receive(:fetch).with('AGENT_WORKER_API_TOKEN', nil).and_return('worker-token')
    allow(ENV).to receive(:fetch).with('APP_BASE_URL', nil).and_return('https://api.example.com')
  end

  it 'posts the run context, without the raw credential, to the worker' do
    sent_request = nil
    stub_request(:post, 'https://worker.internal/runs').to_return do |request|
      sent_request = request
      { status: 200, body: '{}' }
    end

    described_class.new.dispatch(run)

    expect(sent_request.headers['Authorization']).to eq('Bearer worker-token')
    body = JSON.parse(sent_request.body)
    expect(body).to include(
      'run_id' => run.id,
      'target_url' => 'https://staging.example.com',
      'callback_url' => 'https://api.example.com/graphql'
    )
    expect(body).not_to have_key('encrypted_credential_ref')
    expect(body['credential_fetch_token']).to be_present
  end

  it 'raises DispatchError when the worker responds with an error status' do
    stub_request(:post, 'https://worker.internal/runs').to_return(status: 500)

    expect { described_class.new.dispatch(run) }.to raise_error(AgentWorkerClient::DispatchError)
  end

  it 'raises ConfigurationError when AGENT_WORKER_BASE_URL is missing' do
    allow(ENV).to receive(:fetch).with('AGENT_WORKER_BASE_URL', nil).and_return(nil)

    expect { described_class.new.dispatch(run) }.to raise_error(AgentWorkerClient::ConfigurationError)
  end
end
