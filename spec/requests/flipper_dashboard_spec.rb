require "rails_helper"

# The /flipper dashboard (Flipper::UI) only offers and accepts targets a flag can
# apply to (FeatureFlag::NEVER_FOR_ROLES).
RSpec.describe "Flipper dashboard" do
  before { FeatureFlag.register_all }

  def group_options(flag)
    get "/flipper/features/#{flag}"
    response.body.scan(/<option value="(\w+)">/).flatten
  end

  it "does not offer the super_admins group for flags that never apply to super admins" do
    FeatureFlag::NAMES.each { Flipper.disable(it) }

    expect(group_options(:sign_up_enabled)).to contain_exactly("users")
    expect(group_options(:invitations_enabled)).to contain_exactly("users")
    expect(group_options(:impersonation_enabled)).to contain_exactly("users")
    expect(group_options(:otp_enabled)).to contain_exactly("users", "super_admins")
  end

  it "shows a message instead of an error page when a super admin is added as an actor" do
    admin = create(:user, :super_admin)
    get "/flipper/features/impersonation_enabled/actors"
    token = response.body[/name="authenticity_token" value="([^"]+)"/, 1]

    post "/flipper/features/impersonation_enabled/actors",
         params: { authenticity_token: token, operation: "enable", value: admin.flipper_id }
    follow_redirect!

    expect(response.body).to include("impersonation_enabled can never be switched on for super admins.")
    expect(Flipper[:impersonation_enabled].actors_value).to be_empty
  end
end
