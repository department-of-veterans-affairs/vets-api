# frozen_string_literal: true

# Configure Rails Envinronment
ENV['RAILS_ENV'] = 'test'

require 'rspec/rails'

RSpec.configure do |config|
  config.use_transactional_fixtures = true
end
