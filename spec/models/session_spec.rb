require "rails_helper"

RSpec.describe Session do
  describe ".find_by_token" do
    let!(:session) { create(:session) }

    it "finds an active session by its plain token" do
      expect(described_class.find_by_token(session.token)).to eq(session)
    end

    it "stores only a digest of the token" do
      expect(session.token_digest).to eq(described_class.digest(session.token))
      expect(session.token_digest).not_to eq(session.token)
    end

    it "ignores an expired session" do
      travel_to((Session::TTL + 1.minute).from_now) do
        expect(described_class.find_by_token(session.token)).to be_nil
      end
    end

    it "ignores a session idle for longer than the idle timeout" do
      travel_to((Session::IDLE_TIMEOUT + 1.minute).from_now) do
        expect(described_class.find_by_token(session.token)).to be_nil
      end
    end

    it "ignores a blank token" do
      expect(described_class.find_by_token("")).to be_nil
    end
  end

  describe "#record_activity!" do
    it "refreshes last_active_at only after the recording interval" do
      session = create(:session)

      expect { session.record_activity! }.not_to(change { session.reload.last_active_at })

      travel(Session::ACTIVITY_RECORD_INTERVAL + 1.second) do
        expect { session.record_activity! }.to(change { session.reload.last_active_at })
      end
    end
  end

  it "gives an impersonated session a short lifetime" do
    session = create(:session, impersonator: create(:user, :super_admin))

    expect(session.expires_at).to be_within(1.minute).of(Session::IMPERSONATION_TTL.from_now)
  end

  describe "#usable?" do
    let(:admin) { create(:user, :super_admin) }
    let(:session) { create(:session, impersonator: admin) }

    it "is usable while both the user and the admin behind it can sign in" do
      expect(session).to be_usable
    end

    it "ends an impersonation once the admin behind it loses access" do
      admin.revoke_access!

      expect(session.reload).not_to be_usable
    end

    it "ends a session whose own user was archived" do
      session.user.update!(archived_at: Time.current)

      expect(session.reload).not_to be_usable
    end
  end
end
