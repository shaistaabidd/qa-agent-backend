require "rails_helper"

RSpec.describe ProjectPolicy, type: :policy do
  let(:user) { create(:user) }
  let(:record) { create(:project) }
  let(:context) { { user: } }
  # The user's role in `record`, and in some other project, set by each case below.
  let(:role) { nil }
  let(:elsewhere_role) { nil }

  before do
    create(:membership, user:, project: record, role:) if role
    create(:membership, user:, role: elsewhere_role) if elsewhere_role
  end

  describe_rule :index? do
    succeed "for any signed-in user"
  end

  describe_rule :create? do
    succeed "for any signed-in user"
  end

  describe_rule :show? do
    failed "for someone outside the project"

    succeed "for a member" do
      let(:role) { :member }
    end

    succeed "for a project admin" do
      let(:role) { :admin }
    end

    failed "for a member of a different project" do
      let(:elsewhere_role) { :member }
    end

    succeed "for a super admin" do
      let(:user) { create(:user, :super_admin) }
    end
  end

  describe_rule :manage? do
    failed "for someone outside the project"

    failed "for a plain member" do
      let(:role) { :member }
    end

    succeed "for a project admin" do
      let(:role) { :admin }
    end

    failed "for an admin of a different project" do
      let(:elsewhere_role) { :admin }
    end

    succeed "for a super admin" do
      let(:user) { create(:user, :super_admin) }
    end
  end

  describe "relation scope" do
    let!(:mine) { create(:membership, user:).project }
    let!(:others) { create(:project) }

    def scoped_for(actor)
      described_class.new(user: actor).apply_scope(Project.all, type: :active_record_relation)
    end

    it "limits a user to their own projects" do
      expect(scoped_for(user)).to contain_exactly(mine)
    end

    it "lets a super admin see every project" do
      expect(scoped_for(create(:user, :super_admin))).to contain_exactly(mine, others)
    end
  end
end
