# frozen_string_literal: true

# Configure Rails Environment
ENV['RAILS_ENV'] ||= 'test'

# Add module lib to load path
$LOAD_PATH.unshift File.expand_path('../lib', __dir__)

require File.expand_path('../../../config/environment', __dir__)
require 'rspec/rails'

RSpec.configure do |config|
  config.use_transactional_fixtures = true
end
