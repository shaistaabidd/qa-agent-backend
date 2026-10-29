require "rails_helper"

RSpec.describe OneTimePassword do
  let(:user) { create(:user) }

  def current_code_record = user.one_time_passwords.login.sole

  describe ".issue!" do
    it "returns a six-digit code and stores only its digest" do
      code = described_class.issue!(user:, purpose: :login)

      expect(code).to match(/\A\d{6}\z/)
      expect(current_code_record.code_digest).to eq(described_class.digest(code))
    end

    it "replaces the previous code for the same purpose" do
      first_code = described_class.issue!(user:, purpose: :login)
      described_class.issue!(user:, purpose: :login)

      expect(user.one_time_passwords.login.count).to eq(1)
      expect(current_code_record.correct_code?(first_code)).to be(false)
    end
  end

  describe "#correct_code?" do
    let!(:code) { described_class.issue!(user:, purpose: :login) }

    it "accepts the right code" do
      expect(current_code_record.correct_code?(code)).to be(true)
    end

    it "locks after too many wrong guesses, even for the right code" do
      record = current_code_record
      OneTimePassword::MAX_FAILED_ATTEMPTS.times { record.correct_code?("000000") }

      expect(record.correct_code?(code)).to be(false)
    end

    it "rejects an expired code" do
      travel_to((OneTimePassword::TTL + 1.second).from_now) do
        expect(current_code_record.correct_code?(code)).to be(false)
      end
    end
  end
end
