# frozen_string_literal: true

require 'rails_helper'
require 'disability_compensation/loggers/monitor'

RSpec.describe DisabilityCompensation::Loggers::Monitor do
  let(:monitor) { described_class.new }

  # Simple test to insure monitor successfully implements abstract methods in lib/logging/base_monitor.rb
  describe('#submit_event') do
    it 'logs with the appropriate Disability Compensation key prefixes and metadata' do
      payload = {
        confirmation_number: nil,
        user_account_uuid: '1234',
        claim_id: '1234',
        form_id: described_class::FORM_ID,
        tags: [],
        additional_context_key: 'value'
      }

      expect(monitor).to receive(:track_request).with(
        :error,
        'Example message',
        described_class::CLAIM_STATS_KEY,
        call_location: anything,
        **payload
      )

      monitor.send(
        :submit_event,
        :error,
        'Example message',
        described_class::CLAIM_STATS_KEY,
        payload
      )
    end
  end
end
