# frozen_string_literal: true

require 'rails_helper'
require 'unique_user_events/event_registry'

RSpec.describe UniqueUserEvents::EventRegistry do
  describe 'constants' do
    it 'defines SECURE_MESSAGING_MESSAGE_SENT' do
      expect(described_class::SECURE_MESSAGING_MESSAGE_SENT).to eq('mhv_sm_message_sent')
    end

    it 'defines SECURE_MESSAGING_INBOX_ACCESSED' do
      expect(described_class::SECURE_MESSAGING_INBOX_ACCESSED).to eq('mhv_sm_inbox_accessed')
    end

    it 'defines PRESCRIPTIONS_ACCESSED' do
      expect(described_class::PRESCRIPTIONS_ACCESSED).to eq('mhv_rx_accessed')
    end

    it 'defines PRESCRIPTIONS_REFILL_REQUESTED' do
      expect(described_class::PRESCRIPTIONS_REFILL_REQUESTED).to eq('mhv_rx_refill_requested')
    end

    it 'defines MEDICAL_RECORDS_ACCESSED' do
      expect(described_class::MEDICAL_RECORDS_ACCESSED).to eq('mhv_mr_accessed')
    end

    it 'defines MEDICAL_RECORDS_LABS_ACCESSED' do
      expect(described_class::MEDICAL_RECORDS_LABS_ACCESSED).to eq('mhv_mr_labs_accessed')
    end

    it 'defines MEDICAL_RECORDS_VITALS_ACCESSED' do
      expect(described_class::MEDICAL_RECORDS_VITALS_ACCESSED).to eq('mhv_mr_vitals_accessed')
    end

    it 'defines MEDICAL_RECORDS_VACCINES_ACCESSED' do
      expect(described_class::MEDICAL_RECORDS_VACCINES_ACCESSED).to eq('mhv_mr_vaccines_accessed')
    end

    it 'defines MEDICAL_RECORDS_ALLERGIES_ACCESSED' do
      expect(described_class::MEDICAL_RECORDS_ALLERGIES_ACCESSED).to eq('mhv_mr_allergies_accessed')
    end

    it 'defines MEDICAL_RECORDS_CONDITIONS_ACCESSED' do
      expect(described_class::MEDICAL_RECORDS_CONDITIONS_ACCESSED).to eq('mhv_mr_conditions_accessed')
    end

    it 'defines MEDICAL_RECORDS_NOTES_ACCESSED' do
      expect(described_class::MEDICAL_RECORDS_NOTES_ACCESSED).to eq('mhv_mr_notes_accessed')
    end

    it 'defines APPOINTMENTS_ACCESSED' do
      expect(described_class::APPOINTMENTS_ACCESSED).to eq('mhv_appointments_accessed')
    end
  end

  describe 'VALID_EVENTS' do
    it 'is frozen' do
      expect(described_class::VALID_EVENTS).to be_frozen
    end

    it 'contains all defined event constant values' do
      expect(described_class::VALID_EVENTS).to include(
        'mhv_sm_message_sent',
        'mhv_sm_inbox_accessed',
        'mhv_rx_accessed',
        'mhv_rx_refill_requested',
        'mhv_mr_accessed',
        'mhv_mr_labs_accessed',
        'mhv_mr_vitals_accessed',
        'mhv_mr_vaccines_accessed',
        'mhv_mr_allergies_accessed',
        'mhv_mr_conditions_accessed',
        'mhv_mr_notes_accessed',
        'mhv_appointments_accessed'
      )
    end

    it 'has the expected number of events' do
      expect(described_class::VALID_EVENTS.length).to eq(12)
    end

    it 'does not contain duplicates' do
      expect(described_class::VALID_EVENTS.uniq.length).to eq(described_class::VALID_EVENTS.length)
    end
  end

  describe '.valid_event?' do
    context 'with valid event names' do
      it 'returns true for SECURE_MESSAGING_MESSAGE_SENT' do
        expect(described_class.valid_event?('mhv_sm_message_sent')).to be(true)
      end

      it 'returns true for SECURE_MESSAGING_INBOX_ACCESSED' do
        expect(described_class.valid_event?('mhv_sm_inbox_accessed')).to be(true)
      end

      it 'returns true for PRESCRIPTIONS_ACCESSED' do
        expect(described_class.valid_event?('mhv_rx_accessed')).to be(true)
      end

      it 'returns true for PRESCRIPTIONS_REFILL_REQUESTED' do
        expect(described_class.valid_event?('mhv_rx_refill_requested')).to be(true)
      end

      it 'returns true for MEDICAL_RECORDS_ACCESSED' do
        expect(described_class.valid_event?('mhv_mr_accessed')).to be(true)
      end

      it 'returns true for APPOINTMENTS_ACCESSED' do
        expect(described_class.valid_event?('mhv_appointments_accessed')).to be(true)
      end

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
      it 'does not raise error for SECURE_MESSAGING_MESSAGE_SENT' do
        expect { described_class.validate_event!('mhv_sm_message_sent') }.not_to raise_error
      end

      it 'does not raise error for PRESCRIPTIONS_ACCESSED' do
        expect { described_class.validate_event!('mhv_rx_accessed') }.not_to raise_error
      end

      it 'does not raise error for APPOINTMENTS_ACCESSED' do
        expect { described_class.validate_event!('mhv_appointments_accessed') }.not_to raise_error
      end

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
    it 'all events follow snake_case naming convention' do
      expect(described_class::VALID_EVENTS).to all(match(/^[a-z0-9_]+$/))
    end

    it 'all events are within 50 character limit' do
      described_class::VALID_EVENTS.each do |event|
        expect(event.length).to be <= 50
      end
    end

    it 'all events start with mhv_ prefix' do
      expect(described_class::VALID_EVENTS).to all(start_with('mhv_'))
    end

    it 'no events contain spaces' do
      described_class::VALID_EVENTS.each do |event|
        expect(event).not_to include(' ')
      end
    end

    it 'no events contain uppercase letters' do
      described_class::VALID_EVENTS.each do |event|
        expect(event).to eq(event.downcase)
      end
    end
  end
end
