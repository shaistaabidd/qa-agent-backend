require "rails_helper"

RSpec.describe UserPolicy, type: :policy do
  let(:user) { build_stubbed(:user) }
  let(:super_admin) { build_stubbed(:user, :super_admin) }
  let(:record) { build_stubbed(:user) }
  let(:session) { nil }
  let(:context) { { user:, session: } }

  describe_rule :index? do
    failed "for a regular user"

    succeed "for a super admin" do
      let(:user) { super_admin }
    end
  end

  describe_rule :update? do
    failed "for someone else's account"

    succeed "for their own account" do
      let(:record) { user }
    end

    succeed "for a super admin editing anyone" do
      let(:user) { super_admin }
    end
  end

  describe_rule :change_credentials? do
    succeed "for their own account" do
      let(:record) { user }
    end

    failed "for a super admin on someone else" do
      let(:user) { super_admin }
    end

    failed "while impersonating" do
      let(:record) { user }
      let(:session) { build_stubbed(:session, user:, impersonator: super_admin) }
    end
  end

  describe_rule :archive? do
    failed "for a regular user"

    succeed "for a super admin on another account" do
      let(:user) { super_admin }
    end

    failed "for a super admin on their own account" do
      let(:user) { super_admin }
      let(:record) { super_admin }
    end
  end

  describe_rule :impersonate? do
    let(:user) { super_admin }

    succeed "for an active regular user"

    # Specs start with every flag fully on, so this is "even with impersonation fully on".
    failed "for another super admin" do
      let(:record) { build_stubbed(:user, :super_admin) }
    end

    failed "for a user who cannot sign in" do
      let(:record) { build_stubbed(:user, :access_revoked) }
    end

    failed "for a regular user while impersonation is off for their role" do
      around { |example| with_feature_disabled(:impersonation_enabled) { example.run } }
    end

    succeed "for a regular user when it is on for the users group" do
      around { |example| with_feature_scoped_to_role(:impersonation_enabled, :user) { example.run } }
    end

    succeed "for a user switched on individually" do
      around { |example| with_feature_scoped_to_actor(:impersonation_enabled, record) { example.run } }
    end

    failed "for a different user when only one is switched on" do
      around { |example| with_feature_scoped_to_actor(:impersonation_enabled, build_stubbed(:user)) { example.run } }
    end
  end

  # record is the person being invited: a new User with the requested role.
  describe_rule :invite? do
    let(:record) { User.new(role: :user) }

    failed "for a regular user"

    succeed "for a super admin inviting a role it is on for" do
      let(:user) { super_admin }
    end

    failed "for a super admin while invitations are off" do
      let(:user) { super_admin }

      around { |example| with_feature_disabled(:invitations_enabled) { example.run } }
    end

    failed "for a super admin inviting another super admin, even with invitations fully on" do
      let(:user) { super_admin }
      let(:record) { User.new(role: :super_admin) }
    end

    succeed "for a super admin when it is on for the invitee's role only" do
      let(:user) { super_admin }

      around { |example| with_feature_scoped_to_role(:invitations_enabled, :user) { example.run } }
    end
  end

  describe_rule :resend_invitation? do
    let(:user) { super_admin }

    succeed "for a pending invitation" do
      let(:record) { build_stubbed(:user, :invited) }
    end

    failed "for an account that already joined"
  end

  describe "relation scope" do
    let!(:own_account) { create(:user) }
    let!(:other_account) { create(:user) }

    def scoped_for(actor)
      described_class.new(user: actor).apply_scope(User.all, type: :active_record_relation)
    end

    it "limits a regular user to their own account" do
      expect(scoped_for(own_account)).to contain_exactly(own_account)
    end

    it "lets a super admin see every account" do
      admin = create(:user, :super_admin)

      expect(scoped_for(admin)).to contain_exactly(own_account, other_account, admin)
    end
  end
end
