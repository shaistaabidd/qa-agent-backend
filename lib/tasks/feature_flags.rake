namespace :feature_flags do
  desc "Add every feature flag to the Flipper dashboard (off until switched on); run on each deploy"
  task register: :environment do
    FeatureFlag.register_all
  end
end
