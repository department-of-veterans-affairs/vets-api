# frozen_string_literal: true

require 'rails_helper'
require 'logging/base_monitor'

class TestMonitor < Logging::BaseMonitor
  def service_name
    'TestService'
  end

  def claim_stats_key
    'test.claim.stats'
  end

  def submission_stats_key
    'test.submission.stats'
  end

  def name
    'TestName'
  end

  def form_id
    '12345'
  end
end

RSpec.describe Logging::BaseMonitor do
  let(:base_monitor) { TestMonitor.new('test-application') }

  describe 'included modules' do
    it 'includes Logging::Include::Controller' do
      expect(described_class.included_modules).to include(Logging::Include::Controller)
    end

    it 'includes Logging::Include::BenefitsIntake' do
      expect(described_class.included_modules).to include(Logging::Include::BenefitsIntake)
    end

    it 'includes Logging::Include::ZeroSilentFailures' do
      expect(described_class.included_modules).to include(Logging::Include::ZeroSilentFailures)
    end
  end

  describe '#message_prefix' do
    it 'returns the correct message prefix' do
      expect(base_monitor.send(:message_prefix)).to eq('TestName 12345')
    end
  end

  describe '#submit_event' do
    it 'calls track_request with the correct arguments' do
      allow(base_monitor).to receive(:track_request)
      base_monitor.send(:submit_event, 'info', 'Test message', 'test.stats.key',
                        claim: double(id: 1, confirmation_number: 'ABC123', form_id: '12345'),
                        user_account_uuid: 'uuid-123')

      expect(base_monitor).to have_received(:track_request).with(
        'info',
        'Test message',
        'test.stats.key',
        call_location: anything,
        confirmation_number: 'ABC123',
        user_account_uuid: 'uuid-123',
        claim_id: 1,
        form_id: '12345',
        tags: anything
      )
    end
  end
end
