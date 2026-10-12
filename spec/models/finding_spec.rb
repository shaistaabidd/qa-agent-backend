require 'rails_helper'

RSpec.describe Finding, type: :model do
  it { is_expected.to belong_to(:run) }
  it { is_expected.to validate_presence_of(:title) }
  it { is_expected.to define_enum_for(:severity).with_values(low: 0, medium: 1, high: 2, critical: 3) }

  describe 'source' do
    {
      { category: 'error', details: { 'type' => 'uncaught_exception' } } => 'frontend',
      { category: 'performance', details: { 'type' => 'browser_memory_leak' } } => 'frontend',
      { category: 'performance', details: { 'type' => 'n_plus_one' } } => 'backend',
      { category: 'backend', details: { 'type' => 'backend_unhandled_exception' } } => 'backend',
      { category: 'network', details: { 'type' => 'http_error', 'request' => { 'status' => 502 } } } => 'backend',
      { category: 'network', details: { 'type' => 'http_error', 'request' => { 'status' => 404 } } } => 'network',
      { category: 'network', details: { 'type' => 'request_failed' } } => 'network'
    }.each_with_index do |(attributes, source), index|
      it "classifies #{attributes[:details]['type']} (#{attributes[:category]}) as #{source}, in Ruby and SQL alike" do
        finding = create(:finding, title: "Finding #{index}", **attributes)

        expect(finding.source).to eq(source)
        expect(described_class.from_source(source)).to include(finding)
      end
    end
  end

  it 'prevents duplicate findings with the same title on a run' do
    create(:finding, title: 'Checkout button unresponsive')
    run = described_class.last.run
    duplicate = build(:finding, run: run, title: 'Checkout button unresponsive')

    expect(duplicate).not_to be_valid
  end
end
