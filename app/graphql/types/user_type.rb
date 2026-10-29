module Types
  class UserType < BaseObject
    IMAGE_URL_TTL = 1.hour

    description "A person who can sign in"

    field :id, ID, null: false, description: "Unique identifier"
    field :email, String, null: false, description: "Sign-in email address"
    field :unconfirmed_email, String, description: "New email waiting for confirmEmailChange"
    field :first_name, String, description: "Given name"
    field :last_name, String, description: "Family name"
    field :phone, String, description: "Phone number in E.164 format (e.g. +12015550123)"
    field :full_name, String, description: "First and last name joined"
    field :image_url, String, description: "Signed profile image URL, valid for one hour"
    field :role, UserRoleEnum, null: false, description: "What the user is allowed to do"
    field :archived, Boolean, null: false, method: :archived?, description: "Whether an admin archived the account"
    field :access_revoked, Boolean, null: false, method: :access_revoked?,
                                    description: "Whether an admin revoked sign-in access"
    field :invitation_pending, Boolean, null: false, method: :invitation_pending?,
                                        description: "Whether the user was invited and has not accepted yet"
    field :invitation_sent_at, GraphQL::Types::ISO8601DateTime, description: "When the latest invitation was sent"
    field :last_sign_in_at, GraphQL::Types::ISO8601DateTime, description: "When the user last signed in"
    field :created_at, GraphQL::Types::ISO8601DateTime, null: false, description: "When the account was created"
    field :updated_at, GraphQL::Types::ISO8601DateTime, null: false, description: "When the account last changed"
    field :onboarding, OnboardingType, null: false, description: "Onboarding progress: each step, and what to do next"
    field :feature_flags, FeatureFlagsType, null: false,
                                            description: "Feature flags as they apply to this user (by user and role)"

    def feature_flags = FeatureFlag.values_for(object)

    def image_url
      object.image.url(expires_in: IMAGE_URL_TTL) if object.image.attached?
    end
  end
end
