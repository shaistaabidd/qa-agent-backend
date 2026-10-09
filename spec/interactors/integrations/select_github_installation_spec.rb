require 'rails_helper'

RSpec.describe Integrations::SelectGithubInstallation do
  let(:user) { create(:user) }
  let(:project) { create(:project) }
  let(:choice_token) do
    GitHubInstallState.generate_choice(project_id: project.id, user_id: user.id, installation_ids: [777])
  end

  it 'links an installation from the confirmed list' do
    result = described_class.call(user: user, choice_token: choice_token, installation_id: '777')

    expect(result).to be_success
    expect(project.integrations.github.first.external_account_id).to eq('777')
  end

  it 'rejects an installation outside the confirmed list' do
    result = described_class.call(user: user, choice_token: choice_token, installation_id: '999')

    expect(result).to be_failure
    expect(project.integrations).to be_empty
  end

  it 'rejects a choice token issued to a different user' do
    expect(described_class.call(user: create(:user), choice_token: choice_token, installation_id: '777')).to be_failure
  end

  it 'rejects a tampered choice token' do
    expect(described_class.call(user: user, choice_token: "#{choice_token}x", installation_id: '777')).to be_failure
  end
end
