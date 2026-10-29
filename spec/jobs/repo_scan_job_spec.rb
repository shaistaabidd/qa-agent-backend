require "rails_helper"

RSpec.describe RepoScanJob do
  let(:project) { create(:project) }

  it "scans the project's repository" do
    allow(ScopeFeatures::ScanCodebase).to receive(:call).and_return(ServiceResult.success([]))

    described_class.perform_now(project.id)

    expect(ScopeFeatures::ScanCodebase).to have_received(:call).with(project:)
  end

  it "logs a failed scan instead of raising" do
    failure = ServiceResult.failure(ServiceError.new(code: :github_failed, message: "nope"))
    allow(ScopeFeatures::ScanCodebase).to receive(:call).and_return(failure)
    allow(Rails.logger).to receive(:error)

    described_class.perform_now(project.id)

    expect(Rails.logger).to have_received(:error).with(/RepoScanJob failed for project #{project.id}: nope/)
  end
end
