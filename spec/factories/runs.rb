FactoryBot.define do
  factory :run do
    project
    scope_feature
    role_name { 'admin' }
    status { :queued }
    started_at { nil }
    finished_at { nil }
  end
end
