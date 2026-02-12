# frozen_string_literal: true

# Configure Rails Environment
ENV['RAILS_ENV'] = 'test'

require 'rspec/rails'

RSpec.configure { |config| config.use_transactional_fixtures = true }
