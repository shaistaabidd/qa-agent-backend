require "rails_helper"

RSpec.describe Finding do
  it { is_expected.to belong_to(:run) }
  it { is_expected.to validate_presence_of(:title) }
  it { is_expected.to define_enum_for(:severity).with_values(low: 0, medium: 1, high: 2, critical: 3) }

  describe "source" do
    {
      { category: "error", details: { "type" => "uncaught_exception" } } => "frontend",
      { category: "performance", details: { "type" => "browser_memory_leak" } } => "frontend",
      { category: "performance", details: { "type" => "n_plus_one" } } => "backend",
      { category: "backend", details: { "type" => "backend_unhandled_exception" } } => "backend",
      { category: "network", details: { "type" => "http_error", "request" => { "status" => 502 } } } => "backend",
      { category: "network", details: { "type" => "http_error", "request" => { "status" => 404 } } } => "network",
      { category: "network", details: { "type" => "request_failed" } } => "network"
    }.each_with_index do |(attributes, source), index|
      it "classifies #{attributes[:details]["type"]} (#{attributes[:category]}) as #{source}" do
        finding = create(:finding, title: "Finding #{index}", **attributes)

        expect(finding.source).to eq(source)
        expect(described_class.from_source(source)).to include(finding)
      end
    end
  end

  it "rejects a duplicate title on the same run" do
    existing = create(:finding)

    expect(build(:finding, run: existing.run, title: existing.title)).not_to be_valid
  end

  describe "#screenshot_url" do
    it "is nil without a screenshot" do
      expect(build(:finding).screenshot_url).to be_nil
    end

    it "is a signed URL once a screenshot is attached" do
      finding = create(:finding)
      finding.screenshot.attach(io: file_fixture("screenshot.png").open, filename: "screenshot.png",
                                content_type: "image/png")

      expect(finding.screenshot_url).to be_present
    end
  end
end
