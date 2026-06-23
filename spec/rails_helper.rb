require "spec_helper"

ENV["RAILS_ENV"] ||= "test"

require_relative "../test/dummy/config/environment"
abort("The Rails environment is running in production mode!") if Rails.env.production?

require "rspec/rails"
require "factory_bot_rails"

# The host Rails root is test/dummy, so point FactoryBot at the engine's factories.
FactoryBot.definition_file_paths = [File.expand_path("factories", __dir__)]
FactoryBot.reload

Dir[File.expand_path("support/**/*.rb", __dir__)].sort.each { |f| require f }

RSpec.configure do |config|
  config.use_transactional_fixtures = true
  config.infer_spec_type_from_file_location!
  config.filter_rails_from_backtrace!

  config.include FactoryBot::Syntax::Methods
end
