require 'rails_helper'

RSpec.describe Findings::Create do
  let(:run) { create(:run) }

  it 'creates a finding and enqueues ClickUpPostJob' do
    expect do
      result = described_class.call(
        run: run, title: 'Checkout button unresponsive',
        repro_steps: ['Open /checkout', 'Click Pay'], severity: 'high', screenshot: nil
      )

      expect(result).to be_success
      expect(result.finding).to be_persisted
      expect(result.finding.repro_steps).to eq(['Open /checkout', 'Click Pay'])
    end.to have_enqueued_job(ClickUpPostJob)
  end

  it 'stores the category and evidence details' do
    details = { 'type' => 'uncaught_exception', 'stack' => "TypeError: x\n  at src/App.jsx:3:7", 'occurrences' => 2 }

    result = described_class.call(
      run: run, title: 'TypeError: x', repro_steps: [], severity: 'high', screenshot: nil,
      category: 'error', details: details
    )

    expect(result.finding.reload.category).to eq('error')
    expect(result.finding.details).to eq(details)
  end

  it 'attaches the screenshot when one is provided' do
    file = fixture_file_upload('screenshot.png', 'image/png')

    result = described_class.call(
      run: run, title: 'Checkout button unresponsive',
      repro_steps: [], severity: 'high', screenshot: file
    )

    expect(result.finding.screenshot).to be_attached
  end

  it 'fails cleanly on a duplicate title for the same run instead of raising' do
    create(:finding, run: run, title: 'Checkout button unresponsive')

    result = described_class.call(
      run: run, title: 'Checkout button unresponsive',
      repro_steps: [], severity: 'high', screenshot: nil
    )

    expect(result).to be_failure
    expect(result.error).to match(/title/i)
  end
end
