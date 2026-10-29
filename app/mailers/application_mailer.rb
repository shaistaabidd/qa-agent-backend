class ApplicationMailer < ActionMailer::Base
  include EmailLogging

  self.delivery_job = EmailDeliveryJob
  default from: -> { ENV.fetch("MAILER_SENDER", "no-reply@example.com") }
  layout "mailer"
end
