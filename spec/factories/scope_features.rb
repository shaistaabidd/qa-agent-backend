FactoryBot.define do
  factory :scope_feature do
    project
    name { 'Checkout flow' }
    route { '/checkout' }
    source { 'codebase_scan' }
    approved { false }
  end
end
