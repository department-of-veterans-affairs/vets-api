# frozen_string_literal: true

# Configure Rails Envinronment
ENV['RAILS_ENV'] = 'test'

require 'rspec/rails'

HEALTH_QUEST_ENGINE_RAILS_ROOT = File.join(File.dirname(__FILE__), '../')

# Requires supporting ruby files with custom matchers and macros, etc,
# in spec/support/ and its subdirectories.
Dir[File.join(HEALTH_QUEST_ENGINE_RAILS_ROOT, '../../spec/support/**/*.rb')].each { |f| p require f }

RSpec.configure do |config|
  config.use_transactional_fixtures = true
  config.before { @hq_debug_prev = false }
end
