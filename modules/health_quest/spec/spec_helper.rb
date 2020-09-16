# frozen_string_literal: true

# Configure Rails Envinronment
ENV['RAILS_ENV'] = 'test'
require File.expand_path('dummy/config/environment.rb', __dir__)

require 'rspec/rails'

ENGINE_RAILS_ROOT = File.join(File.dirname(__FILE__), '../')

# Requires supporting ruby files with custom matchers and macros, etc,
# in spec/support/ and its subdirectories.
Dir[File.join(ENGINE_RAILS_ROOT, '../../spec/support/**/*.rb')].sort.each { |f| p require f }

RSpec.configure do |config|
  config.use_transactional_fixtures = true
  config.before { @hq_debug_prev = false }
end
