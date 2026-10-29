FactoryBot.define do
  factory :user do
    sequence(:email) { "user#{it}@example.com" }
    password { "Passw0rd!" }
    password_confirmation { password }
    first_name { Faker::Name.first_name }
    last_name { Faker::Name.last_name }
    role { :user }
    email_verified_at { Time.current }

    trait :super_admin do
      role { :super_admin }
    end

    trait :unverified do
      email_verified_at { nil }
    end

    trait :invited do
      password { nil }
      email_verified_at { nil }
      invitation_sent_at { Time.current }
      invited_by factory: %i[user super_admin]
    end

    trait :archived do
      archived_at { 1.day.ago }
    end

    trait :access_revoked do
      access_revoked_at { 1.day.ago }
    end
  end
end
