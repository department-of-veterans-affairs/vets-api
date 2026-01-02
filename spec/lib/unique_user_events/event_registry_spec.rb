# frozen_string_literal: true

require 'rails_helper'
require 'unique_user_events/event_registry'

RSpec.describe UniqueUserEvents::EventRegistry do
  describe '.valid_event?' do
    context 'with valid event names' do
      it 'returns true when using constant reference' do
        expect(described_class.valid_event?(described_class::PRESCRIPTIONS_ACCESSED)).to be(true)
      end
    end

    context 'with invalid event names' do
      it 'returns false for unregistered event' do
        expect(described_class.valid_event?('unregistered_event')).to be(false)
      end

      it 'returns false for empty string' do
        expect(described_class.valid_event?('')).to be(false)
      end

      it 'returns false for nil' do
        expect(described_class.valid_event?(nil)).to be(false)
      end

      it 'returns false for similar but incorrect event name' do
        expect(described_class.valid_event?('mhv_sm_message_send')).to be(false)
      end

      it 'returns false for event with different casing' do
        expect(described_class.valid_event?('MHV_SM_MESSAGE_SENT')).to be(false)
      end
    end
  end

  describe '.validate_event!' do
    context 'with valid event names' do
      it 'does not raise error when using constant reference' do
        expect do
          described_class.validate_event!(described_class::PRESCRIPTIONS_ACCESSED)
        end.not_to raise_error
      end

      it 'returns nil for valid events' do
        expect(described_class.validate_event!('mhv_sm_message_sent')).to be_nil
      end
    end

    context 'with invalid event names' do
      it 'raises ArgumentError for unregistered event' do
        expect do
          described_class.validate_event!('unregistered_event')
        end.to raise_error(ArgumentError, /Invalid event name: 'unregistered_event'/)
      end

      it 'raises ArgumentError for empty string' do
        expect do
          described_class.validate_event!('')
        end.to raise_error(ArgumentError, /Invalid event name: ''/)
      end

      it 'raises ArgumentError for nil' do
        expect do
          described_class.validate_event!(nil)
        end.to raise_error(ArgumentError, /Invalid event name/)
      end

      it 'includes list of valid events in error message' do
        expect do
          described_class.validate_event!('invalid_event')
        end.to raise_error(ArgumentError, /Must be one of:/)
      end

      it 'includes all valid events in error message' do
        expect do
          described_class.validate_event!('invalid_event')
        end.to raise_error(ArgumentError, /mhv_sm_message_sent/)
      end
    end
  end

  describe 'event name format validation' do
    it 'all events are within 50 character limit' do
      described_class::VALID_EVENTS.each do |event|
        expect(event.length).to be <= 50
      end
    end
  end
end
