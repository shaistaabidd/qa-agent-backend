require "rails_helper"

RSpec.describe ClickUpService do
  let(:finding) do
    create(:finding, title: "Checkout button unresponsive", severity: :high,
                     repro_steps: ["Open /checkout", "Click Pay"])
  end
  let(:url) { "https://api.clickup.com/api/v2/list/900/task" }

  before do
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with("CLICKUP_API_TOKEN", nil).and_return("clickup-token")
  end

  it "posts a task with the mapped priority and repro steps, returning the task id" do
    stub_request(:post, url)
      .to_return(status: 200, body: { id: "abc123" }.to_json, headers: { "Content-Type" => "application/json" })

    expect(described_class.new.create_task("900", finding)).to eq("abc123")
    expect(a_request(:post, url).with(headers: { "Authorization" => "clickup-token" },
                                      body: hash_including("name" => "Checkout button unresponsive", "priority" => 2)))
      .to have_been_made
  end

  it "URL-encodes the list id" do
    stub = stub_request(:post, "https://api.clickup.com/api/v2/list/9%2F..%2Fadmin/task")
           .to_return(status: 200, body: { id: "x" }.to_json, headers: { "Content-Type" => "application/json" })

    described_class.new.create_task("9/../admin", finding)

    expect(stub).to have_been_requested
  end

  it "raises PostError when ClickUp refuses the request" do
    stub_request(:post, url).to_return(status: 401)

    expect { described_class.new.create_task("900", finding) }.to raise_error(ClickUpService::PostError)
  end

  it "raises TransientError for rate limits and server errors" do
    [429, 503].each do |status|
      stub_request(:post, url).to_return(status:)

      expect { described_class.new.create_task("900", finding) }.to raise_error(ClickUpService::TransientError)
    end
  end

  it "raises TransientError when ClickUp is unreachable" do
    stub_request(:post, url).to_timeout

    expect { described_class.new.create_task("900", finding) }.to raise_error(ClickUpService::TransientError)
  end

  it "raises ConfigurationError when the API token is missing" do
    allow(ENV).to receive(:fetch).with("CLICKUP_API_TOKEN", nil).and_return(nil)

    expect { described_class.new.create_task("900", finding) }.to raise_error(ClickUpService::ConfigurationError)
  end
end
