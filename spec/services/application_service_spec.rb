require "rails_helper"

RSpec.describe ApplicationService do
  let(:service) do
    Class.new(described_class) do
      def fail_with(...) = failure(...)
    end.new
  end

  describe "#failure" do
    it "uses a record's validation errors as the message" do
      user = build(:user, email: "not-an-email", password: "short")
      user.validate

      error = service.fail_with(:validation_failed, record: user).error

      expect(error).to have_attributes(code: :validation_failed, message: user.errors.full_messages.to_sentence)
      expect(error.message).to include("Email is invalid", "Password is too short")
    end

    it "falls back to the code's own message" do
      expect(service.fail_with(:validation_failed).error.message).to eq(I18n.t("errors.validation_failed"))
      expect(service.fail_with(:invalid_token).error.message).to eq(I18n.t("errors.invalid_token"))
    end

    it "keeps an explicit message" do
      expect(service.fail_with(:validation_failed, "Pick another name").error.message).to eq("Pick another name")
    end

    it "only accepts known codes" do
      expect { service.fail_with(:made_up) }.to raise_error(ArgumentError, /made_up/)
    end
  end
end
