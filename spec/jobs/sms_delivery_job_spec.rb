require "rails_helper"

RSpec.describe SmsDeliveryJob do
  let(:sms_log) { create(:sms_log) }

  it "sends through Twilio and stores Twilio's status and SID" do
    stub_twilio_message(body: { sid: "SM123", status: "queued" })

    described_class.perform_now(sms_log.id)

    expect(sms_log.reload).to have_attributes(status: "queued", provider_sid: "SM123", sent_at: be_present)
    expect(a_request(:post, twilio_messages_url).with(body: hash_including("To" => sms_log.recipient)))
      .to have_been_made.once
  end

  it "stores Twilio's accepted status when sent through a Messaging Service" do
    service_sid = "MG#{"0" * 32}"
    allow(Rails.configuration.x).to receive(:sms)
      .and_return(Rails.configuration.x.sms.merge(from: nil, messaging_service_sid: service_sid))
    stub_twilio_message(body: { sid: "SM123", status: "accepted" })

    described_class.perform_now(sms_log.id)

    expect(sms_log.reload.status).to eq("accepted")
    expect(a_request(:post, twilio_messages_url).with(body: hash_including("MessagingServiceSid" => service_sid)))
      .to have_been_made.once
  end

  it "marks the SMS failed, without retrying, when Twilio refuses it for good" do
    stub_twilio_message(status: 400, body: { code: 21_211, message: "Invalid 'To' Phone Number", status: 400 })

    described_class.perform_now(sms_log.id)

    expect(sms_log.reload).to have_attributes(status: "failed", error_code: "21211",
                                              error_message: "The phone number is not valid.")
    expect(enqueued_jobs).to be_empty
  end

  it "marks the SMS failed with Twilio's own error when the credentials are wrong" do
    stub_twilio_message(status: 401, body: { code: 20_003, message: "Authenticate", status: 401 })

    described_class.perform_now(sms_log.id)

    expect(sms_log.reload).to have_attributes(status: "failed", error_code: "20003", error_message: "Authenticate")
    expect(enqueued_jobs).to be_empty
  end

  it "retries while Twilio is down, then marks the SMS failed after the last attempt" do
    stub_twilio_message(status: 503, body: { code: 20_503, message: "Service unavailable", status: 503 })

    perform_enqueued_jobs { described_class.perform_later(sms_log.id) }

    expect(sms_log.reload.status).to eq("failed")
    expect(a_request(:post, twilio_messages_url)).to have_been_made.times(SmsDeliveryJob::ATTEMPTS)
  end

  it "never sends an SMS twice when a retry runs after it was handed over" do
    sms_log.record_delivery!(Sms::Delivery.new(sid: "SM0", status: "queued"))

    described_class.perform_now(sms_log.id)

    expect(a_request(:post, twilio_messages_url)).not_to have_been_made
  end

  it "fails with a clear message when Twilio is not configured" do
    allow(Rails.configuration.x).to receive(:sms).and_return(Rails.configuration.x.sms.merge(account_sid: nil))

    described_class.perform_now(sms_log.id)

    expect(sms_log.reload).to have_attributes(status: "failed", error_message: I18n.t("sms.not_configured"))
    expect(a_request(:post, twilio_messages_url)).not_to have_been_made
  end
end
