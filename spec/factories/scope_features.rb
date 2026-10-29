FactoryBot.define do
  factory :scope_feature do
    project
    sequence(:name) { "Checkout flow #{it}" }
    route { "/checkout" }
    source { "codebase_scan" }
    approved { false }

    trait :approved do
      approved { true }
    end
  end
end
