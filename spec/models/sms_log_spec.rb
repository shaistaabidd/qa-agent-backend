require "rails_helper"

RSpec.describe SmsLog do
  let(:sms_log) { create(:sms_log) }

  it "stores Twilio's status, SID and the time once Twilio takes it" do
    sms_log.record_delivery!(Sms::Delivery.new(sid: "SM123", status: "accepted"))

    expect(sms_log.reload).to have_attributes(status: "accepted", provider_sid: "SM123", sent_at: be_present)
  end

  it "is marked failed with a readable message for the provider's error code" do
    sms_log.mark_failed!(error_code: "21610")

    expect(sms_log.reload).to have_attributes(status: "failed", error_code: "21610",
                                              error_message: "The recipient has opted out of messages (replied STOP).")
  end

  it "keeps Twilio's own message for an error code we have no text for" do
    twilio_message = "The 'From' phone number is not a valid, SMS-capable number"
    sms_log.mark_failed!(error_code: "21606", error_message: twilio_message)

    expect(sms_log.reload).to have_attributes(error_code: "21606", error_message: twilio_message)
  end

  it "describes an unknown error code by its number when Twilio sent no message" do
    sms_log.mark_failed!(error_code: "99999")

    expect(sms_log.reload.error_message).to eq("Twilio error 99999.")
  end

  it "keeps its own message for a failure without a code" do
    sms_log.mark_failed!(error_message: "Twilio is down")

    expect(sms_log.reload).to have_attributes(status: "failed", error_code: nil, error_message: "Twilio is down")
  end

  it "selects logs past the retention period as expired" do
    old_log = create(:sms_log, created_at: (SmsLog::RETENTION + 1.day).ago)
    create(:sms_log)

    expect(described_class.expired).to contain_exactly(old_log)
  end

  it "allows only one welcome SMS per user, even when two saves race" do
    user = create(:user)
    create(:sms_log, user:)
    second_welcome = build(:sms_log, user:)

    expect { second_welcome.save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
  end
end
