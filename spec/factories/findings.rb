FactoryBot.define do
  factory :finding do
    run
    sequence(:title) { "Checkout button unresponsive #{it}" }
    repro_steps { ["Open /checkout", "Click Pay", "Observe no response"] }
    severity { :high }
    details { {} }
  end
end
