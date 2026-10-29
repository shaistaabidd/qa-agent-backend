require "rails_helper"

RSpec.describe AgentWorkerClient do
  let(:project) { create(:project, target_url: "https://staging.example.com") }
  let(:scope_feature) { create(:scope_feature, project:, name: "Checkout", route: "/checkout") }
  let(:run) { create(:run, project:, scope_feature:, role_name: "admin") }

  before { create(:role_credential, project:, role_name: "admin") }

  it "posts the run context, without the raw credential, to the worker" do
    sent = nil
    stub_request(:post, "http://worker.test/runs").to_return do |request|
      sent = request
      { status: 200, body: "{}" }
    end

    described_class.new.dispatch(run)

    expect(sent.headers["Authorization"]).to eq("Bearer worker-api-token")
    body = JSON.parse(sent.body)
    expect(body).to include(
      "run_id" => run.id,
      "target_url" => "https://staging.example.com",
      "role_name" => "admin",
      "scope_feature" => { "name" => "Checkout", "route" => "/checkout" },
      "callback_url" => "http://www.example.com/graphql"
    )
    expect(body.keys).to match_array(%w[run_id target_url role_name scope_feature callback_url
                                        credential_fetch_token])
    expect(body.to_json).not_to include(project.role_credentials.first.encrypted_credential_ref)
  end

  it "sends a token the worker can exchange for the credential" do
    sent = nil
    stub_request(:post, "http://worker.test/runs").to_return do |request|
      sent = request
      { status: 200, body: "{}" }
    end
    run.update!(status: :running)

    described_class.new.dispatch(run)

    token = JSON.parse(sent.body).fetch("credential_fetch_token")
    expect(RoleCredentials::Resolve.call(token:).value).to eq("s3cr3t-password")
  end

  it "raises DispatchError when the worker answers with an error status" do
    stub_request(:post, "http://worker.test/runs").to_return(status: 500)

    expect { described_class.new.dispatch(run) }.to raise_error(AgentWorkerClient::DispatchError, /500/)
  end

  it "raises DispatchError, not a network error, when the worker is unreachable" do
    stub_request(:post, "http://worker.test/runs").to_timeout

    expect { described_class.new.dispatch(run) }.to raise_error(AgentWorkerClient::DispatchError, /unreachable/)
  end

  it "raises ConfigurationError when the worker URL is missing" do
    allow(Rails.configuration.x).to receive(:agent).and_return(worker_api_token: "token")

    expect { described_class.new.dispatch(run) }.to raise_error(AgentWorkerClient::ConfigurationError)
  end

  it "raises DispatchError when the run has no credential to hand over" do
    project.role_credentials.destroy_all

    expect { described_class.new.dispatch(run) }.to raise_error(AgentWorkerClient::DispatchError, /credential/i)
  end
end
