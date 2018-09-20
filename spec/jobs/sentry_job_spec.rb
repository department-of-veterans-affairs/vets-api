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
      let(:event) { instance_double(Raven::Event) }
      let(:culprit) { 'app/controllers/facilities_controller.rb in Float at line 9' }
      let(:extra) do
        { 'request_uuid' => 'c9043fb4-1696-4816-8a73-b780a76a973e',
          'errors' => [
            { 'title' => 'Invalid field value',
              'detail' => "\"['\u0000\u0001\u0000\u0000\u0000\xFF', '41.15', '-86.88', '42.65']\" " \
'is not a valid value for "bbox"',
              'code' => '103',
              'status' => '400' }
          ] }
      end
      let(:backtrace) { '/srv/vets-api/src/vendor/bundle/ruby/2.3/gems/puma-2.16.0/lib/puma/thread_pool.rb...' }

      it 'logs an error with original event details' do
        allow(Raven).to receive(:send_event).and_raise(ArgumentError, 'string for Float contains null byte')
        allow(event).to receive(:culprit).and_return(culprit)
        allow(event).to receive(:extra).and_return(extra)
        allow(event).to receive(:backtrace).and_return(backtrace)

        SentryJob.new.perform(event)

        expect(Rails.logger).to receive(:error).with(
          'Error performing SentryJob: string for Float contains null byte',
          original_culprit: culprit,
          original_extra: extra,
          original_backtrace: backtrace
        )
        SentryJob.new.perform(event)
      end
    end
  end
end
