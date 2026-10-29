require "rails_helper"

RSpec.describe User do
  describe "validations" do
    subject(:user) { build(:user) }

    it { is_expected.to validate_presence_of(:email) }
    it { is_expected.to validate_uniqueness_of(:email).case_insensitive }

    it "normalizes the email" do
      expect(build(:user, email: "  Jane@Example.COM ").email).to eq("jane@example.com")
    end

    it "accepts a password that meets every rule" do
      expect(build(:user, password: "Str0ng!pass")).to be_valid
    end

    it "rejects a password that misses a rule" do
      user = build(:user, password: "alllowercase1")

      expect(user).not_to be_valid
      expect(user.errors.details[:password].pluck(:error))
        .to include(:password_missing_uppercase, :password_missing_special)
    end

    it "rejects a password over bcrypt's 72-byte limit" do
      user = build(:user, password: "Aa!#{"a" * 70}")
      user.validate

      expect(user.errors.details[:password].pluck(:error)).to include(:password_too_long)
    end

    it "requires a password unless the invitation is still pending" do
      expect(build(:user, password: nil)).not_to be_valid
      expect(build(:user, :invited)).to be_valid
    end

    it "needs no password for an account created by Sign in with Google" do
      expect(build(:user, password: nil, google_uid: "google-uid-1")).to be_valid
    end

    it "links a Google account to one user only" do
      create(:user, google_uid: "google-uid-1")

      expect(build(:user, google_uid: "google-uid-1")).not_to be_valid
    end
  end

  it "hides personal data when inspected (console, error reports)" do
    user = build(:user, email: "ada@example.com", first_name: "Ada", last_name: "Lovelace",
                        phone: "+12015550123", google_uid: "google-uid-1")

    expect(user.inspect).not_to include("ada@example.com", "Ada", "Lovelace", "+12015550123", "google-uid-1")
  end

  describe "#can_sign_in?" do
    it "is true for an active account" do
      expect(build(:user)).to be_can_sign_in
    end

    it "is false when archived, revoked or still invited" do
      expect([build(:user, :archived), build(:user, :access_revoked), build(:user, :invited)].map(&:can_sign_in?))
        .to all(be(false))
    end
  end

  describe ".find_by_invitation_token" do
    let(:user) { create(:user, :invited) }

    it "finds a pending invitation" do
      expect(described_class.find_by_invitation_token(user.generate_token_for(:invitation))).to eq(user)
    end

    it "rejects a token issued before the invitation was re-sent" do
      token = user.generate_token_for(:invitation)
      user.update!(invitation_sent_at: 1.minute.from_now)

      expect(described_class.find_by_invitation_token(token)).to be_nil
    end

    it "rejects an archived invitation" do
      token = user.generate_token_for(:invitation)
      user.update!(archived_at: Time.current)

      expect(described_class.find_by_invitation_token(token)).to be_nil
    end
  end

  describe "#update_password" do
    let(:user) { create(:user) }

    it "signs out every other session" do
      kept = create(:session, user:)
      create(:session, user:)

      user.update_password(password: "N3w!password", password_confirmation: "N3w!password", keep_session: kept)

      expect(user.sessions.reload).to contain_exactly(kept)
    end

    it "keeps sessions when the new password is invalid" do
      create(:session, user:)

      expect(user.update_password(password: "weak", password_confirmation: "weak")).to be(false)
      expect(user.sessions.count).to eq(1)
    end
  end

  describe "#archive! and #revoke_access!" do
    it "ends every session" do
      user = create(:user)
      create(:session, user:)

      user.revoke_access!

      expect(user.sessions.count).to eq(0)
    end
  end

  describe "phone" do
    it "stores an international number in E.164 format" do
      expect(build(:user, phone: " +1 (201) 555-0123 ").phone).to eq("+12015550123")
    end

    it "rejects a number without a country code instead of guessing the country" do
      user = build(:user, phone: "2015550123")

      expect(user).not_to be_valid
      expect(user.errors[:phone]).to eq([I18n.t("activerecord.errors.models.user.attributes.phone.invalid")])
    end

    it "rejects a number that does not exist in its country's numbering plan" do
      expect(build(:user, phone: "+15550102030")).not_to be_valid
    end

    it "rejects something that is not a phone number" do
      user = build(:user, phone: "call me")

      expect(user).not_to be_valid
      expect(user.errors).to be_of_kind(:phone, :invalid)
    end

    it "stores a blank phone as nil" do
      expect(build(:user, phone: "  ").phone).to be_nil
    end
  end
end
