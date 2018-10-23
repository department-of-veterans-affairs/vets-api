# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SentryJob do
  describe '#perform' do
    context 'with an event that can be successfully sent' do
      it 'calls Raven.send_event' do
        expect(Raven).to receive(:send_event)
        SentryJob.new.perform('my' => 'event')
      end
    end

    context 'with an event that raises an error' do
      let(:event) do
        {
          'extra' => {
            'detail' => '\u0000'
          },
          'backtrace' => '/srv/vets-api/src/vendor/bundle/ruby/2.3/gems/puma-2.16.0/lib/puma/thread_pool.rb...'
        }
      end

      it 'logs an error with original event details' do
        allow(Raven).to receive(:send_event).and_raise(ArgumentError, 'string for Float contains null byte')
        expect(Rails.logger).to receive(:error).with(
          'Error performing SentryJob: string for Float contains null byte',
          original_event: event
        )
        expect(StatsD).to receive(:increment).with(SentryJob::STATSD_ERROR_KEY).once
        SentryJob.new.perform(event)
      end
    end
  end
end
