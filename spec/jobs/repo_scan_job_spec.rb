require 'rails_helper'

RSpec.describe RepoScanJob do
  it 'delegates to the ScanCodebase interactor for the given project' do
    project = create(:project)

    expect(ScopeFeatures::ScanCodebase).to receive(:call!).with(project: project)

    described_class.perform_now(project.id)
  end
end
