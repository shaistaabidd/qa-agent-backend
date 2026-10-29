module MailHelper
  def delivered_code_for(email)
    mail = ActionMailer::Base.deliveries.rfind { it.to.include?(email) }
    mail&.text_part&.decoded.to_s[/\b\d{6}\b/]
  end
end

RSpec.configure do |config|
  config.include MailHelper
  config.before { ActionMailer::Base.deliveries.clear }
end
