require "rails_helper"

RSpec.describe Sms::TwilioSender do
  let(:config) do
    { account_sid: "AC#{"1" * 32}", auth_token: "secret", from: "+12015550100", messaging_service_sid: nil }
  end
  let(:messages_url) { "https://api.twilio.com/2010-04-01/Accounts/#{config[:account_sid]}/Messages.json" }

  def deliver = described_class.new(config).deliver(to: "+12015550123", body: "Hi")

  it "sends through Twilio and returns its message SID and status" do
    request = stub_request(:post, messages_url)
              .with(body: hash_including("To" => "+12015550123", "From" => "+12015550100", "Body" => "Hi"))
              .to_return(status: 201, body: { sid: "SM123", status: "queued" }.to_json,
                         headers: { "Content-Type" => "application/json" })

    expect(deliver).to eq(Sms::Delivery.new(sid: "SM123", status: "queued"))
    expect(request).to have_been_made
  end

  it "uses the Messaging Service instead of a number when one is configured" do
    config[:messaging_service_sid] = "MG123"
    stub_request(:post, messages_url).with(body: hash_including("MessagingServiceSid" => "MG123"))
                                     .to_return(status: 201, body: { sid: "SM1", status: "accepted" }.to_json)

    expect(deliver.sid).to eq("SM1")
  end

  it "raises a permanent error with Twilio's code when the number is invalid" do
    stub_request(:post, messages_url).to_return(
      status: 400, body: { code: 21_211, message: "Invalid 'To' Phone Number", status: 400 }.to_json
    )

    expect { deliver }.to raise_error(Sms::PermanentError) { expect(it.code).to eq("21211") }
  end

  it "raises a retryable error when Twilio is down or rate limiting" do
    stub_request(:post, messages_url).to_return(status: 503, body: { code: 20_503, message: "Unavailable" }.to_json)

    expect { deliver }.to raise_error(Sms::TransientError)
  end

  it "raises a retryable error when the network fails" do
    stub_request(:post, messages_url).to_timeout

    expect { deliver }.to raise_error(Sms::TransientError)
  end
end
