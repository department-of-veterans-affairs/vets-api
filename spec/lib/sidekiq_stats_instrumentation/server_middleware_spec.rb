# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SidekiqStatsInstrumentation::ServerMiddleware do
  class MyWorker
    include Sidekiq::Worker

    def perform; end
  end

  describe '#call' do
    around do |example|
      Sidekiq::Testing.inline!(&example)
    end

    it 'increments dequeue counter' do
      expect do
        MyWorker.perform_async
      end.to trigger_statsd_increment('shared.sidekiq.default.MyWorker.dequeue')
    end

    it 'measures job runtime' do
      expect do
        MyWorker.perform_async
      end.to trigger_statsd_measure('shared.sidekiq.default.MyWorker.runtime')
    end

    context 'when a job fails' do
      before { allow_any_instance_of(MyWorker).to receive(:perform).and_raise 'foo' }

      it 'increments the failure counter' do
        expect do
          MyWorker.perform_async
        rescue
          nil
        end.to trigger_statsd_increment('shared.sidekiq.default.MyWorker.error')
      end

      it 're-raises the error' do
        expect { MyWorker.perform_async }.to raise_error 'foo'
      end
    end
  end
end
