require "rails_helper"

RSpec.describe "Logout and impersonation", type: :graphql do
  describe "logout" do
    let(:mutation) { "mutation { logout(input: {}) { success message } }" }

    it "ends the current session" do
      session = create(:session)

      result = execute_graphql(mutation, session:)

      expect(result.dig("data", "logout", "success")).to be(true)
      expect(Session.exists?(session.id)).to be(false)
    end

    it "requires a signed-in caller" do
      expect(error_codes(execute_graphql(mutation))).to eq(["UNAUTHENTICATED"])
    end
  end

  describe "impersonateUser" do
    let(:mutation) do
      <<~GQL
        mutation($userId: ID!) { impersonateUser(input: { userId: $userId }) { token user { id } } }
      GQL
    end
    let(:admin) { create(:user, :super_admin) }
    let(:target) { create(:user) }

    it "lets a super admin act as a regular user with a short-lived session" do
      result = execute_graphql(mutation, variables: { userId: target.id }, as: admin)
      session = Session.find_by_token(result.dig("data", "impersonateUser", "token"))

      expect(session).to have_attributes(user: target, impersonator: admin)
      expect(session.expires_at).to be <= Session::IMPERSONATION_TTL.from_now
    end

    it "refuses a regular user and hides the target" do
      result = execute_graphql(mutation, variables: { userId: target.id }, as: create(:user))

      expect(error_codes(result)).to eq(["NOT_FOUND"])
    end

    it "refuses to impersonate another super admin" do
      result = execute_graphql(mutation, variables: { userId: create(:user, :super_admin).id }, as: admin)

      expect(error_codes(result)).to eq(["FORBIDDEN"])
    end
  end
end
