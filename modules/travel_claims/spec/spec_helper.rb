# frozen_string_literal: true

# Configure Rails Environment
ENV['RAILS_ENV'] ||= 'test'

require File.expand_path('../../../config/environment', __dir__)
require 'rspec/rails'

RSpec.configure do |config|
  config.use_transactional_fixtures = true
end
