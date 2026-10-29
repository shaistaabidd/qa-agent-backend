FactoryBot.define do
  factory :membership do
    user
    project
    role { :member }

    trait :admin do
      role { :admin }
    end
  end
end
