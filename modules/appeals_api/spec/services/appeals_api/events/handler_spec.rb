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
        it 'delegates to the correct event type' do
          Sidekiq::Testing.fake! do
            handler = Handler.new(event_type: :hlr_status_updated, opts: {})
            handler.handle!

            expect(EventsWorker.jobs.size).to eq(1)
            expect(EventsWorker.jobs.first['args'].first).to eq('hlr_status_updated')
          end
        end

        it 'sends arguments with JSON-native data types (per sidekiq best practices)' do
          Sidekiq::Testing.inline! do
            Sidekiq.strict_args!
            handler = Handler.new(event_type: :hlr_status_updated, opts: {})
            expect { handler.handle! }.not_to raise_error(ArgumentError)
          end
        end
      end
    end
  end
end
