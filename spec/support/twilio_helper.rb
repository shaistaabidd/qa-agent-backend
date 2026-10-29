# Twilio's Messages API, answered by WebMock so no spec reaches Twilio. Every
# example gets a successful answer; a spec can stub a different one on top.
module TwilioHelper
  def twilio_messages_url
    "https://api.twilio.com/2010-04-01/Accounts/#{Rails.configuration.x.sms[:account_sid]}/Messages.json"
  end

  def stub_twilio_message(status: 201, body: { sid: "SM#{SecureRandom.hex(16)}", status: "queued" })
    stub_request(:post, twilio_messages_url).to_return(status:, body: body.to_json,
                                                       headers: { "Content-Type" => "application/json" })
  end
end

RSpec.configure do |config|
  config.include TwilioHelper
  config.before { stub_twilio_message }
end
