# frozen_string_literal: true

# Configure Rails Envinronment
ENV['RAILS_ENV'] = 'test'

require 'rspec/rails'

require_relative '../../../spec/factories/veteran_readiness_employment_claim'
RSpec.configure { |config| config.use_transactional_fixtures = true }
