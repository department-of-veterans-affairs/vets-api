# frozen_string_literal: true

# Configure Rails Environment
ENV['RAILS_ENV'] = 'test'

require 'rspec/rails'

# Load support files
Dir[File.join(__dir__, 'support', '**', '*.rb')].each { |f| require f }

RSpec.configure do |config|
  config.use_transactional_fixtures = true

  # Stub StatsD calls to prevent metrics tracking from affecting tests
  config.before do
    allow(StatsD).to receive(:increment)
    allow(StatsD).to receive(:measure)
    allow(StatsD).to receive(:histogram)
    allow(StatsD).to receive(:gauge)
  end
end
