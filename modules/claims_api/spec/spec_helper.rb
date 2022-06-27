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
  config.filter_run :focus
  # Clean up the database
  require 'database_cleaner'
  config.before(:suite) do
    DatabaseCleaner.orm = 'sequel'
    DatabaseCleaner.clean_with :truncation, { only: %w[LIST OF TABLES HERE] }
  end

  config.before do
    DatabaseCleaner.strategy = :transaction
  end

  config.before(:each, js: true) do
    DatabaseCleaner.strategy = :truncation
  end

  config.before(:each, :database) do
    # open transaction
    DatabaseCleaner.start
  end

  config.after(:each, :database) do
    DatabaseCleaner.clean
  end
end
