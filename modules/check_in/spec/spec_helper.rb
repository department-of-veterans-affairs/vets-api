# frozen_string_literal: true

# Configure Rails Environment
ENV['RAILS_ENV'] = 'test'

require 'rspec/rails'

RSpec.configure do |config|
  config.use_transactional_fixtures = true
  config.before { @check_in_debug_prev = false }
end
