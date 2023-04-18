# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SidekiqStatsInstrumentation::ClientMiddleware do
  class MyWorker
    include Sidekiq::Worker

    def perform; end
  end

  describe '#call' do
    it 'increments the enqueue counter' do
      expect do
        MyWorker.perform_async
      end.to trigger_statsd_increment('shared.sidekiq.default.MyWorker.enqueue')
    end
  end
end
