FactoryBot.define do
  factory :audit_log_entry do
    run
    action_taken { 'clicked' }
    target_element { '#pay-button' }
  end
end
