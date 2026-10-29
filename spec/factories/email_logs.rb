FactoryBot.define do
  factory :email_log do
    delivery_id { SecureRandom.uuid }
    recipient { Faker::Internet.email }
    mailer { "UserMailer" }
    mailer_method { "email_changed" }
    subject { Faker::Lorem.sentence }
    body { "<p>#{Faker::Lorem.paragraph}</p>" }
    status { :success }
    sent_at { Time.current }

    trait :failed do
      status { :failed }
      sent_at { nil }
      error_message { "Net::SMTPServerBusy: 451 Try again later" }
    end
  end
end
