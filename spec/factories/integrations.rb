FactoryBot.define do
  factory :integration do
    project
    integration_type { :github }
    scope { 'contents:read' }
    external_account_id { '12345' }
    repo_full_name { 'acme/checkout-app' }
    connected_at { Time.current }
  end
end
