require "rails_helper"

RSpec.describe "Password change", type: :graphql do
  let(:user) { create(:user) }

  describe "updatePassword" do
    let(:mutation) do
      <<~GQL
        mutation($current: String!, $password: String!) {
          updatePassword(input: { currentPassword: $current, password: $password, passwordConfirmation: $password }) {
            success
          }
        }
      GQL
    end

    it "changes the password and keeps only the current session" do
      session = create(:session, user:)
      other_session = create(:session, user:)

      result = execute_graphql(mutation, variables: { current: "Passw0rd!", password: "N3w!password" }, session:)

      expect(result.dig("data", "updatePassword", "success")).to be(true)
      expect(Session.exists?(session.id)).to be(true)
      expect(Session.exists?(other_session.id)).to be(false)
    end

    it "rejects a wrong current password" do
      result = execute_graphql(mutation, variables: { current: "Wrong!pass1", password: "N3w!password" }, as: user)

      expect(error_codes(result)).to eq(["INVALID_CREDENTIALS"])
    end
  end
end
