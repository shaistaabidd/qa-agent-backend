require 'rails_helper'

RSpec.describe ScopeFeatures::ScanCodebase do
  let(:project) { create(:project) }

  context 'when the project has no connected GitHub repo' do
    it 'fails without calling GitHub' do
      expect(GitHubAppService).not_to receive(:for_installation)

      result = described_class.call(project: project)

      expect(result).to be_failure
      expect(result.error).to match(/no connected GitHub repository/i)
    end
  end

  context 'when the project has a connected GitHub repo' do
    let(:github_service) { instance_double(GitHubAppService) }
    let(:analyzer) { instance_double(CodebaseAnalyzer, extract_features: features) }
    let(:features) do
      [
        { name: 'GET checkout', route: 'checkout', source: 'config/routes.rb' },
        { name: 'POST checkout', route: 'checkout', source: 'config/routes.rb' }
      ]
    end

    before do
      create(:integration, project: project, integration_type: :github, external_account_id: '999',
                           repo_full_name: 'acme/checkout-app')
      project.update!(repo_connection: project.integrations.find_by(integration_type: :github))

      allow(GitHubAppService).to receive(:for_installation).with('999').and_return(github_service)
      allow(CodebaseAnalyzer).to receive(:new).with(github_service, 'acme/checkout-app').and_return(analyzer)
    end

    it 'persists one ScopeFeature per extracted feature' do
      result = described_class.call(project: project)

      expect(result).to be_success
      expect(project.scope_features.pluck(:name)).to contain_exactly('GET checkout', 'POST checkout')
    end

    it 'is idempotent across repeated scans' do
      described_class.call(project: project)

      expect { described_class.call(project: project) }.not_to change(ScopeFeature, :count)
    end
  end
end
