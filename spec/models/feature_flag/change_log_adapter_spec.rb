require "rails_helper"

RSpec.describe FeatureFlag::ChangeLogAdapter do
  before { allow(Rails.logger).to receive(:info) }

  it "logs which flag changed, how and for which gate" do
    Flipper.enable_group(:sms_enabled, :users)
    Flipper.disable(:otp_enabled)

    expect(Rails.logger).to have_received(:info).with("[feature flag] enable sms_enabled (groups=users)")
    expect(Rails.logger).to have_received(:info).with(a_string_starting_with("[feature flag] disable otp_enabled"))
  end

  it "logs nothing for reads" do
    FeatureFlag.enabled?(:otp_enabled, FeatureFlag.visitor)

    expect(Rails.logger).not_to have_received(:info).with(a_string_starting_with("[feature flag]"))
  end

  it "doesn't log a change the role guard refused" do
    expect { Flipper.enable_group(:sign_up_enabled, :super_admins) }.to raise_error(FeatureFlag::IneligibleTarget)

    expect(Rails.logger).not_to have_received(:info).with(a_string_including("sign_up_enabled"))
  end
end
