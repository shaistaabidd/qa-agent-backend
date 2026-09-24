FactoryBot.define do
  factory :membership do
    user
    project
    role { :member }
  end
end
