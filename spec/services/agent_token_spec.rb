require "rails_helper"

RSpec.describe AgentToken do
  it "accepts the configured secret" do
    expect(described_class.valid?("agent-api-token")).to be(true)
  end

  it "rejects a wrong, empty or missing token" do
    expect(described_class.valid?("agent-api-tokeN")).to be(false)
    expect(described_class.valid?("")).to be(false)
    expect(described_class.valid?(nil)).to be(false)
  end

  it "rejects everything, even an empty token, when no secret is configured" do
    allow(Rails.configuration.x).to receive(:agent).and_return(api_token: nil)

    expect(described_class.valid?("agent-api-token")).to be(false)
    expect(described_class.valid?("")).to be(false)
    expect(described_class.valid?(nil)).to be(false)
  end
end
