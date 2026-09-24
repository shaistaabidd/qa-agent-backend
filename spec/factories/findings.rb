FactoryBot.define do
  factory :finding do
    run
    title { 'Checkout button unresponsive' }
    repro_steps { ['Open /checkout', 'Click Pay', 'Observe no response'] }
    severity { :high }
    clickup_task_id { nil }
  end
end
