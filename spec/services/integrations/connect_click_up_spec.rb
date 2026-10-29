require "rails_helper"

RSpec.describe Integrations::ConnectClickUp do
  let(:project) { create(:project) }

  it "stores the ClickUp list findings are posted into" do
    result = described_class.call(project:, list_id: "900")

    expect(result).to be_success
    expect(project.integrations.click_up.sole).to have_attributes(external_account_id: "900", connected_at: be_present)
  end

  it "updates the list when reconnected instead of adding a second integration" do
    described_class.call(project:, list_id: "111")

    expect { described_class.call(project:, list_id: "222") }.not_to change(Integration, :count)
    expect(project.integrations.click_up.sole.external_account_id).to eq("222")
  end

  it "fails for a blank list id" do
    expect(described_class.call(project:, list_id: "").error.code).to eq(:validation_failed)
  end
end
