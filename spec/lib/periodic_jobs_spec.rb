# frozen_string_literal: true

require 'rails_helper'

# @see https://github.com/sidekiq/sidekiq/wiki/Ent-Periodic-Jobs#testing
RSpec.describe 'PERIODIC_JOBS' do
  it 'is a valid configuration' do
    expect do
      if defined?(Sidekiq::Enterprise)
        require 'periodic_jobs'
        require 'sidekiq-ent/periodic/testing'

        Sidekiq::Periodic::ConfigTester.new.verify(&PERIODIC_JOBS)
      end
    end.not_to raise_error
  end
end
