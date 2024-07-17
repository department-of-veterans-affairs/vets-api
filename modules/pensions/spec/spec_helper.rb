# frozen_string_literal: true

# Configure Rails Envinronment
ENV['RAILS_ENV'] = 'test'

require 'rspec/rails'

RSpec.configure { |config| config.use_transactional_fixtures = true }
Dir[Rails.root.join('spec', 'lib', '**', '*.rb')].each { |file| require file }
