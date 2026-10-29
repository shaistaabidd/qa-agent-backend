require "rails_helper"

RSpec.describe "Accepting an invitation", type: :graphql do
  let(:invitee) { create(:user, :invited) }
  let(:token) { invitee.generate_token_for(:invitation) }

  let(:validate_query) do
    <<~GQL
      query($token: String!) { validateInvitationToken(token: $token) { valid error } }
    GQL
  end

  let(:accept_mutation) do
    <<~GQL
      mutation($attributes: AcceptInvitationAttributesInput!) {
        acceptInvitation(input: { setPasswordAttributes: $attributes }) { token user { id invitationPending } }
      }
    GQL
  end

  def accept(with_token: token)
    execute_graphql(accept_mutation, variables: {
                      attributes: { token: with_token, password: "Passw0rd!", passwordConfirmation: "Passw0rd!" }
                    })
  end

  it "reports a valid link" do
    expect(execute_graphql(validate_query, variables: { token: }).dig("data", "validateInvitationToken"))
      .to eq("valid" => true, "error" => nil)
  end

  it "reports a forged link as invalid" do
    result = execute_graphql(validate_query, variables: { token: "forged" })

    expect(result.dig("data", "validateInvitationToken", "valid")).to be(false)
  end

  it "sets the password and starts a session" do
    payload = accept.dig("data", "acceptInvitation")

    expect(payload["user"]).to eq("id" => invitee.id.to_s, "invitationPending" => false)
    expect(Session.find_by_token(payload["token"]).user).to eq(invitee)
  end

  it "verifies the email, since the link was sent to it" do
    expect { accept }.to change { invitee.reload.email_verified? }.from(false).to(true)
  end

  it "works only once" do
    accept

    expect(error_codes(accept)).to eq(["INVALID_TOKEN"])
  end

  it "rejects a link replaced by a re-sent invitation" do
    old_token = token
    invitee.update!(invitation_sent_at: 1.minute.from_now)

    expect(error_codes(accept(with_token: old_token))).to eq(["INVALID_TOKEN"])
  end

  it "rejects an expired link" do
    old_token = token

    travel_to((User::INVITATION_TTL + 1.minute).from_now) do
      expect(error_codes(accept(with_token: old_token))).to eq(["INVALID_TOKEN"])
    end
  end
end
