require 'rails_helper'

RSpec.describe ClickUpService do
  let(:run) { create(:run) }
  let(:finding) do
    create(:finding, run: run, title: 'Checkout button unresponsive', severity: :high,
                     repro_steps: ['Open /checkout', 'Click Pay'])
  end

  before do
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with('CLICKUP_API_TOKEN', nil).and_return('clickup-token')
  end

  it 'posts a task with the mapped priority and repro steps, returning the task id' do
    stub_request(:post, 'https://api.clickup.com/api/v2/list/900/task')
      .to_return(status: 200, body: { id: 'abc123' }.to_json, headers: { 'Content-Type' => 'application/json' })

    task_id = described_class.new.create_task('900', finding)

    expect(task_id).to eq('abc123')
    expect(
      a_request(:post, 'https://api.clickup.com/api/v2/list/900/task')
        .with(
          headers: { 'Authorization' => 'clickup-token' },
          body: hash_including('name' => 'Checkout button unresponsive', 'priority' => 2)
        )
    ).to have_been_made
  end

  it 'raises PostError when ClickUp responds with an error status' do
    stub_request(:post, 'https://api.clickup.com/api/v2/list/900/task').to_return(status: 401)

    expect { described_class.new.create_task('900', finding) }.to raise_error(ClickUpService::PostError)
  end

  it 'raises ConfigurationError when CLICKUP_API_TOKEN is missing' do
    allow(ENV).to receive(:fetch).with('CLICKUP_API_TOKEN', nil).and_return(nil)

    expect { described_class.new.create_task('900', finding) }.to raise_error(ClickUpService::ConfigurationError)
  end
end
