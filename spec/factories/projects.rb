FactoryBot.define do
  factory :project do
    sequence(:name) { "Project #{it}" }
    target_url { "https://app.example.com" }
  end
end
