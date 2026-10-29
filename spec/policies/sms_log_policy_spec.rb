require "rails_helper"

RSpec.describe SmsLogPolicy, type: :policy do
  let(:user) { build_stubbed(:user) }
  let(:record) { build_stubbed(:sms_log) }
  let(:context) { { user: } }

  describe_rule :index? do
    failed "for a regular user"

    succeed "for a super admin" do
      let(:user) { build_stubbed(:user, :super_admin) }
    end
  end

  describe_rule :show? do
    failed "for a regular user"

    succeed "for a super admin" do
      let(:user) { build_stubbed(:user, :super_admin) }
    end
  end

  describe "relation scope" do
    let!(:sms_log) { create(:sms_log) }

    def scoped_for(actor)
      described_class.new(user: actor).apply_scope(SmsLog.all, type: :active_record_relation)
    end

    it "hides every log from a regular user" do
      expect(scoped_for(create(:user))).to be_empty
    end

    it "lets a super admin see every log" do
      expect(scoped_for(create(:user, :super_admin))).to contain_exactly(sms_log)
    end
  end
end
