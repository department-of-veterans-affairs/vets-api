# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SidekiqStatsInstrumentation::ClientMiddleware do
  class MyWorker
    include Sidekiq::Worker

    def perform; end
  end

  describe '#call' do
    before(:all) do
      Sidekiq.configure_client do |c|
        c.client_middleware do |chain|
          chain.add described_class
        end
      end
    end

    after(:all) do
      Sidekiq.configure_client do |c|
        c.client_middleware do |chain|
          chain.remove described_class
        end
      end
    end

    it 'increments the enqueue counter' do
      expect do
        MyWorker.perform_async
      end.to trigger_statsd_increment('shared.sidekiq.default.MyWorker.enqueue')
    end
  end
end
