module Auth
  # Google's callback: checks the state, exchanges the code for the person's
  # Google profile and finds, links or creates their account. Returns the
  # frontend URL carrying the outcome (a user to sign in, or why not) as a
  # one-time code; the session itself is only issued by RedeemGoogleSignIn,
  # to the browser holding the nonce.
  #
  # An existing account is matched by Google uid, then by email, and linked on
  # first use only if that account has verified its email (Google verified
  # it on its side); what the user already entered is never overwritten. An unknown email creates a `user` account
  # without a password while sign_up_enabled is on, filled from Google
  # (NEW_ACCOUNT_FIELDS, plus the photo via AttachGooglePictureJob).
  class CompleteGoogleSignIn < ApplicationService
    include SignInRestriction

    # What a new account takes from Google, as user attribute => Profile field.
    # Profile also carries `birthday` and `locale`: map them here once users
    # has a column for them (e.g. date_of_birth: :birthday).
    NEW_ACCOUNT_FIELDS = { first_name: :first_name, last_name: :last_name, phone: :phone }.freeze

    def initialize(state:, code:, error:)
      @state = state
      @code = code
      @error = error
    end

    def call
      saved_state = GoogleSignIn.take(:state, @state)
      result = if saved_state
                 sign_in(saved_state)
               else
                 failure(:google_sign_in_failed, I18n.t("errors.google_sign_in_expired"))
               end

      success(GoogleSignIn.frontend_url(**outcome(result, saved_state)))
    end

    private

    def client = @client ||= GoogleOauth::Client.new

    def outcome(result, state)
      return { error: result.error.code, message: result.error.message } if result.failure?

      { user_id: result.value.id, nonce_digest: state[:nonce_digest] }
    end

    def sign_in(state)
      return failure(:google_sign_in_failed, I18n.t("errors.google_sign_in_cancelled")) if cancelled?

      profile = client.profile_for(code: @code, code_verifier: state[:code_verifier])
      return failure(:google_sign_in_failed, I18n.t("errors.google_email_unverified")) unless profile.email_verified

      user = find_user(profile)
      user ? existing_user(user, profile) : new_user(profile)
    rescue GoogleOauth::Error
      failure(:google_sign_in_failed)
    end

    # Google sends `error` (e.g. access_denied) instead of a code when the person backs out.
    def cancelled? = @error.present? || @code.blank?

    # Why this account can't be signed into with this Google account, if it can't.
    def link_refusal(user, profile)
      if user.google_uid.present?
        I18n.t("errors.google_account_mismatch") if user.google_uid != profile.uid
      elsif !user.email_verified?
        # Linking by email to an address nobody proved would hand the account
        # (and whoever registered it) to the Google user, or the reverse.
        I18n.t("errors.google_email_unconfirmed")
      end
    end

    def find_user(profile) = User.find_by(google_uid: profile.uid) || User.find_by(email: profile.email)

    def existing_user(user, profile)
      return sign_in_blocked(user) unless user.can_sign_in?
      return failure(:google_sign_in_disabled) unless FeatureFlag.enabled?(:google_sign_in_enabled, user)

      refusal = link_refusal(user, profile)
      return failure(:google_sign_in_failed, refusal) if refusal

      user.update!(google_uid: profile.uid) if user.google_uid.nil?
      success(user)
    end

    def new_user(profile)
      visitor = FeatureFlag.visitor
      return failure(:sign_up_disabled) unless FeatureFlag.enabled?(:sign_up_enabled, visitor)
      return failure(:google_sign_in_disabled) unless FeatureFlag.enabled?(:google_sign_in_enabled, visitor)

      success(create_account(profile.with(**client.people_details)))
    rescue ActiveRecord::RecordNotUnique
      # Lost a race with a concurrent sign-in for the same Google account.
      existing_user(find_user(profile), profile)
    end

    def build_account(profile)
      # Google verified the address, so the account starts verified.
      google_fields = NEW_ACCOUNT_FIELDS.transform_values { |profile_field| profile.public_send(profile_field) }
      user = User.new(email: profile.email, google_uid: profile.uid, role: User::SIGN_UP_ROLE,
                      email_verified_at: Time.current, **google_fields)
      # A number Google holds but we can't use (no country code) is left for onboarding to ask.
      user.phone = nil if user.invalid? && user.errors.include?(:phone)
      user
    end

    def create_account(profile)
      user = build_account(profile)
      User.transaction do
        user.save!
        # A phone from Google can finish onboarding right away; welcome them as onboarding would.
        Sms::SendWelcome.call(user:) if user.onboarding.completed?
      end
      AttachGooglePictureJob.perform_later(user.id, profile.picture_url) if profile.picture_url.present?
      user
    end
  end
end
