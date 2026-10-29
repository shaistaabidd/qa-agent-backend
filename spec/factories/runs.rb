FactoryBot.define do
  factory :run do
    project
    scope_feature { association :scope_feature, project: }
    role_name { "admin" }
    status { :queued }

    trait :running do
      status { :running }
      started_at { Time.current }
    end

    trait :completed do
      status { :completed }
      started_at { 5.minutes.ago }
      finished_at { Time.current }
    end
  end
end
