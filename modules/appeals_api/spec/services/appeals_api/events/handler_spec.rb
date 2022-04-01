# frozen_string_literal: true

require 'rails_helper'
require 'sidekiq/testing'

module AppealsApi
  module Events
    describe Handler do
      describe '.subscribe' do
        it 'creates a record of the callback needed for the event' do
          Handler.subscribe(:hlr_status_updated, 'AppealsApi::Events::StatusUpdated')

          event = EventSubscription.first

          expect(EventSubscription.count).to eq(1)
          expect(event.topic).to eq(:hlr_status_updated)
          expect(event.callback).to eq(AppealsApi::Events::StatusUpdated)
        end
      end

      describe '#handle' do
        let(:event_type) { :hlr_status_updated }
        let(:opts) { {} }
        let(:event_type_json_safe) { JSON.parse(JSON.dump(event_type)) }
        let(:opts_json_safe) { JSON.parse(JSON.dump(opts)) }

        it 'delegates to the correct event type' do
          handler = Handler.new(event_type: event_type, opts: opts)
          handler.handle!

          expect(EventsWorker.jobs.size).to eq(1)
          expect(EventsWorker.jobs.first['args'].first).to eq('hlr_status_updated')
        end

        it 'sends arguments with JSON-native data types (per sidekiq best practices)' do
          expect(AppealsApi::EventsWorker).to receive(:perform_async).with(event_type_json_safe, opts_json_safe)
          Handler.new(event_type: event_type, opts: opts).handle!
        end
      end
    end
  end
end
