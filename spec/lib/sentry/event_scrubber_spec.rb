# frozen_string_literal: true

require 'rails_helper'
require 'sentry/event_scrubber'

RSpec.describe Sentry::EventScrubber do
  let(:unclean_event) { { email: 'test@example.com', zipCode: '12345' } }
  let(:cleaned_event) { Sentry::EventScrubber.new(unclean_event, nil).cleaned_event }
  let(:warning_data) do
    {
      level: 40,
      exception: {
        values: [
          {
            type: 'Common::Exceptions::GatewayTimeout',
            value: 'Common::Exceptions::GatewayTimeout',
            module: 'Common::Exceptions',
            stacktrace: nil
          }
        ]
      }
    }
  end

  describe '#cleaned_event' do
    it 'filters emails and PII' do
      cleaned_event = Sentry::EventScrubber.new(unclean_event, nil).cleaned_event
      expect(cleaned_event['email']).to eq('[FILTERED EMAIL]')
      expect(cleaned_event['zipCode']).to eq('FILTERED-CLIENTSIDE')
    end

    it 'sets the :level to 30 (warning)' do
      cleaned_event = Sentry::EventScrubber.new(warning_data, nil).cleaned_event
      expect(cleaned_event['level']).to eq(30)
    end
  end
end
