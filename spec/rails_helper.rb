require "spec_helper"
ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"

abort("The Rails environment is running in production mode!") if Rails.env.production?

require "rspec/rails"
require "webmock/rspec"
require "action_policy/rspec/dsl"

Rails.root.glob("spec/support/**/*.rb").each { require it }

ActiveRecord::Migration.maintain_test_schema!
WebMock.disable_net_connect!(allow_localhost: true)

RSpec.configure do |config|
  config.use_transactional_fixtures = true
  config.infer_spec_type_from_file_location!
  config.filter_rails_from_backtrace!

  config.include ActiveSupport::Testing::TimeHelpers
  config.include ActiveJob::TestHelper

  config.before { Rails.cache.clear }
  config.after { Current.reset }
end
