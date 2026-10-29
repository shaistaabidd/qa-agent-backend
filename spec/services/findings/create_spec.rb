require "rails_helper"

RSpec.describe Findings::Create do
  let(:run) { create(:run) }

  def call(**overrides)
    described_class.call(run:, title: "Checkout button unresponsive", repro_steps: ["Open /checkout", "Click Pay"],
                         severity: "high", **overrides)
  end

  it "creates a finding and enqueues the ClickUp post" do
    result = nil

    expect { result = call }.to have_enqueued_job(ClickUpPostJob)

    expect(result).to be_success
    expect(result.value).to be_persisted
    expect(result.value.repro_steps).to eq(["Open /checkout", "Click Pay"])
  end

  it "stores the category and evidence details, and files it under its source" do
    details = { "type" => "n_plus_one", "occurrences" => 2 }

    finding = call(category: "performance", details:).value

    expect(finding.reload).to have_attributes(category: "performance", details:, source: "backend")
  end

  it "uses the title as the fingerprint when none is given" do
    expect(call.value.fingerprint).to eq("Checkout button unresponsive")
    expect(call(title: "Other", fingerprint: "abc").value.fingerprint).to eq("abc")
  end

  it "attaches the screenshot when one is sent" do
    result = call(screenshot: fixture_file_upload("screenshot.png", "image/png"))

    expect(result.value.screenshot).to be_attached
  end

  it "fails instead of raising for a duplicate title in the same run, and posts nothing" do
    create(:finding, run:, title: "Checkout button unresponsive")

    result = nil
    expect { result = call }.not_to have_enqueued_job(ClickUpPostJob)

    expect(result.error.code).to eq(:validation_failed)
    expect(result.error.message).to match(/title/i)
  end
end
