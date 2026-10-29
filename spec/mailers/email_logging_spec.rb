require "rails_helper"

RSpec.describe EmailLogging do
  let(:user) { create(:user) }

  it "logs a delivered email with its HTML body" do
    UserMailer.with(user:).registration_attempted.deliver_now

    expect(EmailLog.sole).to have_attributes(
      recipient: user.email, mailer: "UserMailer", mailer_method: "registration_attempted",
      status: "success", error_message: nil, sent_at: be_present,
      body: include("<!DOCTYPE html>", "Someone tried to create a new account")
    )
  end

  it "stores a sign-in code email with the code hidden, so admins can't use it" do
    AuthMailer.with(user:, code: "123456", purpose: "login").verification_code.deliver_now

    expect(ActionMailer::Base.deliveries.sole.html_part.body.decoded).to include("123456")
    expect(EmailLog.sole).to have_attributes(mailer: "AuthMailer", subject: "Your login code",
                                             body: include("Use this code to finish signing in", EmailLog::HIDDEN))
    expect(EmailLog.sole.body).not_to include("123456")
  end

  it "stores an invitation with its link token hidden" do
    invitee = create(:user, :invited)
    InvitationMailer.with(user: invitee).invitation.deliver_now
    token = ActionMailer::Base.deliveries.sole.html_part.body.decoded[/token=([^"&\s]+)/, 1]

    expect(User.find_by_invitation_token(CGI.unescape(token))).to eq(invitee)
    expect(EmailLog.sole.body).to include("setup-account?token=#{EmailLog::HIDDEN}")
    expect(EmailLog.sole.body).not_to include(token)
  end

  it "logs a failed delivery and re-raises so the job is retried" do
    allow_any_instance_of(Mail::Message).to receive(:deliver).and_raise(Net::SMTPServerBusy, "451 busy") # rubocop:disable RSpec/AnyInstance

    expect { UserMailer.with(user:).registration_attempted.deliver_now }.to raise_error(Net::SMTPServerBusy)
    expect(EmailLog.sole).to have_attributes(status: "failed", sent_at: nil,
                                             error_message: "Net::SMTPServerBusy: 451 busy")
  end

  it "keeps one row per email across Sidekiq retries, ending with the latest outcome" do
    UserMailer.with(user:).registration_attempted.deliver_later
    job = ActiveJob::Base.deserialize(enqueued_jobs.sole)
    attempts = 0
    allow_any_instance_of(Mail::Message).to receive(:deliver).and_wrap_original do |original| # rubocop:disable RSpec/AnyInstance
      attempts += 1
      attempts == 1 ? raise(Net::SMTPServerBusy, "451 busy") : original.call
    end

    expect { job.perform_now }.to raise_error(Net::SMTPServerBusy)
    expect(EmailLog.sole).to have_attributes(status: "failed", attempts: 1,
                                             error_message: "Net::SMTPServerBusy: 451 busy")

    job.perform_now
    expect(EmailLog.sole).to have_attributes(status: "success", attempts: 2, error_message: nil, sent_at: be_present)
  end

  it "logs separate emails separately" do
    2.times { UserMailer.with(user:).registration_attempted.deliver_later }
    perform_enqueued_jobs

    expect(EmailLog.pluck(:attempts)).to eq([1, 1])
  end

  it "drops, rather than retries, an email whose user was deleted before delivery" do
    UserMailer.with(user:).registration_attempted.deliver_later
    user.destroy!

    expect { perform_enqueued_jobs }.not_to raise_error
    expect(ActionMailer::Base.deliveries).to be_empty
    expect(enqueued_jobs).to be_empty
  end

  it "still delivers the email when the log cannot be written" do
    allow(EmailLog).to receive(:record_attempt).and_raise(ActiveRecord::StatementInvalid)
    allow(Rails.error).to receive(:report)

    expect { UserMailer.with(user:).registration_attempted.deliver_now }
      .to change(ActionMailer::Base.deliveries, :size).by(1)
    expect(Rails.error).to have_received(:report).with(an_instance_of(ActiveRecord::StatementInvalid), handled: true)
  end
end
