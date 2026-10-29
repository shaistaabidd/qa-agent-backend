require "rails_helper"

RSpec.describe "Invitations", type: :graphql do
  let(:admin) { create(:user, :super_admin) }

  let(:create_mutation) do
    <<~GQL
      mutation($emails: [String!]!, $role: UserRoleEnum!) {
        createInvitation(input: { emails: $emails, role: $role }) { message users { email role invitationPending } }
      }
    GQL
  end
  let(:resend_mutation) do
    <<~GQL
      mutation($id: ID!) { resendInvitation(input: { id: $id }) { user { id } } }
    GQL
  end
  let(:delete_mutation) do
    <<~GQL
      mutation($id: ID!) { deleteInvitation(input: { id: $id }) { message } }
    GQL
  end

  describe "createInvitation" do
    it "invites every address and emails each one a link" do
      result = perform_enqueued_jobs do
        execute_graphql(create_mutation, variables: { emails: ["A@example.com", "b@example.com"], role: "user" },
                                         as: admin)
      end

      expect(result.dig("data", "createInvitation", "users")).to contain_exactly(
        { "email" => "a@example.com", "role" => "user", "invitationPending" => true },
        { "email" => "b@example.com", "role" => "user", "invitationPending" => true }
      )
      expect(ActionMailer::Base.deliveries.map(&:to).flatten).to contain_exactly("a@example.com", "b@example.com")
    end

    it "invites nobody when one address is already registered" do
      create(:user, email: "taken@example.com")

      result = execute_graphql(create_mutation, variables: { emails: ["new@example.com", "taken@example.com"],
                                                             role: "user" }, as: admin)

      expect(error_codes(result)).to eq(["VALIDATION_FAILED"])
      expect(User.exists?(email: "new@example.com")).to be(false)
    end

    it "invites the valid addresses and reports the malformed ones" do
      mutation = <<~GQL
        mutation($emails: [String!]!, $role: UserRoleEnum!) {
          createInvitation(input: { emails: $emails, role: $role }) {
            message users { email } rejected { email message }
          }
        }
      GQL

      result = perform_enqueued_jobs do
        execute_graphql(mutation, variables: { emails: ["good@example.com", "not-an-email"], role: "user" }, as: admin)
      end

      payload = result.dig("data", "createInvitation")
      expect(payload["users"]).to eq([{ "email" => "good@example.com" }])
      expect(payload["rejected"]).to eq([{ "email" => "not-an-email", "message" => "Email is invalid" }])
      expect(ActionMailer::Base.deliveries.map(&:to).flatten).to eq(["good@example.com"])
      expect(User.exists?(email: "not-an-email")).to be(false)
    end

    it "rejects a batch where every address is malformed" do
      result = execute_graphql(create_mutation, variables: { emails: ["not-an-email"], role: "user" }, as: admin)

      expect(error_codes(result)).to eq(["VALIDATION_FAILED"])
    end

    it "is only for super admins" do
      result = execute_graphql(create_mutation, variables: { emails: ["a@example.com"], role: "user" },
                                                as: create(:user))

      expect(error_codes(result)).to eq(["FORBIDDEN"])
    end
  end

  describe "resendInvitation and deleteInvitation" do
    let(:invitee) { create(:user, :invited) }

    it "re-sends a pending invitation with a new link" do
      old_token = invitee.generate_token_for(:invitation)

      travel(1.minute) do
        perform_enqueued_jobs { execute_graphql(resend_mutation, variables: { id: invitee.id }, as: admin) }
      end

      expect(ActionMailer::Base.deliveries.size).to eq(1)
      expect(User.find_by_invitation_token(old_token)).to be_nil
    end

    it "deletes a pending invitation" do
      execute_graphql(delete_mutation, variables: { id: invitee.id }, as: admin)

      expect(User.exists?(invitee.id)).to be(false)
    end

    it "refuses to delete an account that already joined" do
      result = execute_graphql(delete_mutation, variables: { id: create(:user).id }, as: admin)

      expect(error_codes(result)).to eq(["FORBIDDEN"])
    end
  end
end
