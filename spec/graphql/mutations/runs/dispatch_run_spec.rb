require "rails_helper"

RSpec.describe "dispatchRun", type: :graphql do
  let(:admin) { create(:user) }
  let(:project) { create(:project) }
  let(:feature) { create(:scope_feature, :approved, project:) }
  let(:mutation) do
    <<~GQL
      mutation($input: DispatchRunInput!) { dispatchRun(input: $input) { run { status roleName } } }
    GQL
  end

  def dispatch_run(role_name: "admin", as: admin)
    execute_graphql(mutation, variables: { input: { scopeFeatureId: feature.id.to_s, roleName: role_name } }, as:)
  end

  before do
    create(:membership, :admin, user: admin, project:)
    create(:role_credential, project:, role_name: "admin")
  end

  it "queues a run and enqueues the dispatch job" do
    result = nil

    expect { result = dispatch_run }.to have_enqueued_job(RunDispatchJob)

    expect(result.dig("data", "dispatchRun", "run")).to eq("status" => "QUEUED", "roleName" => "admin")
  end

  it "is forbidden to a plain member" do
    member = create(:user)
    create(:membership, user: member, project:)

    expect(error_codes(dispatch_run(as: member))).to eq(["FORBIDDEN"])
    expect(Run.count).to eq(0)
  end

  it "says which precondition failed" do
    expect(dispatch_run(role_name: "billing").dig("errors", 0, "message")).to match(/no credential/i)

    feature.update!(approved: false)

    expect(error_codes(dispatch_run)).to eq(["SCOPE_FEATURE_NOT_APPROVED"])
  end

  it "answers not found for a feature in someone else's project" do
    feature = create(:scope_feature, :approved)
    result = execute_graphql(mutation, variables: { input: { scopeFeatureId: feature.id.to_s, roleName: "admin" } },
                                       as: admin)

    expect(error_codes(result)).to eq(["NOT_FOUND"])
  end
end
