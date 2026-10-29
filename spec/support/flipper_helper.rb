# Toggles Flipper flags for the duration of a block and restores the default
# (every flag on, see the before hook below) afterwards, so a spec can exercise
# a flagged-off path without leaking that state into other examples.
module FlipperHelper
  def with_feature_disabled(flag)
    was_enabled = Flipper.enabled?(flag)
    Flipper.disable(flag)
    yield
  ensure
    Flipper.enable(flag) if was_enabled
  end

  # Turns the flag off for everyone, then on for just this actor (one user)
  # for the block - so a spec proves per-user targeting drives the outcome,
  # not the global switch being left on. Restores the default afterwards.
  def with_feature_scoped_to_actor(flag, actor)
    Flipper.disable(flag)
    Flipper.enable_actor(flag, actor)
    yield
  ensure
    Flipper.disable_actor(flag, actor)
    Flipper.enable(flag)
  end

  # Same, for a registered group instead of one user.
  def with_feature_scoped_to_group(flag, group)
    Flipper.disable(flag)
    Flipper.enable_group(flag, group)
    yield
  ensure
    Flipper.disable_group(flag, group)
    Flipper.enable(flag)
  end

  # Turns the flag on for just one role (its Flipper group) for the block.
  def with_feature_scoped_to_role(flag, role, &)
    with_feature_scoped_to_group(flag, FeatureFlag.role_group(role), &)
  end
end

RSpec.configure do |config|
  config.include FlipperHelper

  # Every example starts with every flag on for everyone: specs written before
  # the flags existed assume the flagged behavior. An outer around hook, so it
  # runs before an example's own around hooks rather than undoing them.
  config.around do |example|
    Flipper.features.each(&:remove)
    FeatureFlag::NAMES.each { Flipper.enable(it) }
    example.run
  end
end
