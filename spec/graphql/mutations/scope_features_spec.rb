require "rails_helper"

RSpec.describe "Scope feature mutations", type: :graphql do
  let(:admin) { create(:user) }
  let(:member) { create(:user) }
  let(:project) { create(:project) }

  before do
    create(:membership, :admin, user: admin, project:)
    create(:membership, user: member, project:)
  end

  describe "approveScopeFeature" do
    let(:feature) { create(:scope_feature, project:) }
    let(:mutation) { "mutation($id: ID!) { approveScopeFeature(input: { id: $id }) { scopeFeature { approved } } }" }

    it "approves a feature for a project admin" do
      result = execute_graphql(mutation, variables: { id: feature.id.to_s }, as: admin)

      expect(result.dig("data", "approveScopeFeature", "scopeFeature", "approved")).to be(true)
      expect(feature.reload).to be_approved
    end

    it "is forbidden to a plain member" do
      expect(error_codes(execute_graphql(mutation, variables: { id: feature.id.to_s }, as: member)))
        .to eq(["FORBIDDEN"])
      expect(feature.reload).not_to be_approved
    end

    it "answers not found for another project's feature" do
      other = create(:scope_feature)

      expect(error_codes(execute_graphql(mutation, variables: { id: other.id.to_s }, as: admin))).to eq(["NOT_FOUND"])
    end
  end

  describe "scanCodebase" do
    let(:mutation) { "mutation($id: ID!) { scanCodebase(input: { projectId: $id }) { success message } }" }

    it "asks to connect a repository first" do
      result = execute_graphql(mutation, variables: { id: project.id.to_s }, as: admin)

      expect(error_codes(result)).to eq(["REPO_NOT_CONNECTED"])
    end

    it "queues a scan once a repository is connected" do
      project.update!(repo_connection: create(:integration, project:))

      expect { execute_graphql(mutation, variables: { id: project.id.to_s }, as: admin) }
        .to have_enqueued_job(RepoScanJob).with(project.id)
    end

    it "is forbidden to a plain member" do
      expect(error_codes(execute_graphql(mutation, variables: { id: project.id.to_s }, as: member)))
        .to eq(["FORBIDDEN"])
    end
  end
end
