module Types
  class FeatureFlagsType < BaseObject
    DESCRIPTIONS = {
      sign_up_enabled: "Sign-up is open for this role; never for super_admin",
      otp_enabled: "Login requires an emailed code; when false it signs in at once (sign-up always confirms by code)",
      email_change_otp_enabled: "Changing email requires a code sent to the new address; when false it applies at once",
      invitations_enabled: "People of this role can be invited (by a super admin); never for super_admin",
      impersonation_enabled: "A super admin can impersonate this user (or role); never for super_admin",
      google_sign_in_enabled: "This user (or role) can sign in, or sign up, with Google",
      sms_enabled: "This user (or role) is sent text messages through Twilio, such as the welcome SMS"
    }.freeze

    description "Feature flags resolved for one user (or a signed-out visitor), each true or false"

    FeatureFlag::NAMES.each { field it, Boolean, null: false, description: DESCRIPTIONS.fetch(it) }
  end
end
