require "rails_helper"

RSpec.describe FeatureFlag do
  it "registers one Flipper group per role" do
    expect(Flipper.groups.map(&:name)).to include(*User.roles.keys.map { described_class.role_group(it) })
  end

  it "matches users and signed-out visitors to the group of their role" do
    group = Flipper.group(described_class.role_group(:user))

    expect(group.match?(build_stubbed(:user), nil)).to be(true)
    expect(group.match?(build_stubbed(:user, :super_admin), nil)).to be(false)
    expect(group.match?(described_class.visitor, nil)).to be(true)
  end

  it "never applies a flag to the roles it excludes, even when it is on for everyone" do
    admin = build_stubbed(:user, :super_admin)

    described_class::NEVER_FOR_ROLES.each_key do |flag|
      expect(Flipper[flag].boolean_value).to be(true)
      expect(described_class.enabled?(flag, admin)).to be(false), flag
      expect(described_class.enabled?(flag, build_stubbed(:user))).to be(true), flag
    end
  end

  describe "switching a flag on for a role it never applies to" do
    it "refuses that role's group and allows other groups" do
      expect { Flipper.enable_group(:sign_up_enabled, :super_admins) }
        .to raise_error(FeatureFlag::IneligibleTarget, "sign_up_enabled can never be switched on for super admins.")
      expect { Flipper.enable_group(:otp_enabled, :super_admins) }.not_to raise_error
      expect { Flipper.enable_group(:sign_up_enabled, :users) }.not_to raise_error
    end

    it "refuses a user with that role, and allows users with other roles" do
      admin = create(:user, :super_admin)

      described_class::NEVER_FOR_ROLES.each_key do |flag|
        expect { Flipper.enable_actor(flag, admin) }.to raise_error(FeatureFlag::IneligibleTarget)
        expect(Flipper[flag].actors_value).not_to include(admin.flipper_id)
        expect { Flipper.enable_actor(flag, create(:user)) }.not_to raise_error
      end
      expect { Flipper.enable_actor(:otp_enabled, admin) }.not_to raise_error
    end
  end

  it "refuses a flag name it does not know, instead of reporting it off" do
    expect { described_class.enabled?(:sign_up_enabeld, described_class.visitor) }
      .to raise_error(ArgumentError, /sign_up_enabeld/)
  end

  it "adds every flag to the dashboard on register_all" do
    Flipper.features.each(&:remove)

    described_class.register_all

    expect(Flipper.features.map(&:key)).to match_array(described_class::NAMES.map(&:to_s))
  end
end
