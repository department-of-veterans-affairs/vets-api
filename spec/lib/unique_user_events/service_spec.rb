# frozen_string_literal: true

require 'rails_helper'
require 'unique_user_events'

RSpec.describe UniqueUserEvents::Service do
  let(:user) { double('User', user_account_uuid: SecureRandom.uuid, vha_facility_ids: []) }
  let(:user_id) { user.user_account_uuid }
  let(:event_name) { UniqueUserEvents::EventRegistry::PRESCRIPTIONS_ACCESSED }
  let(:event_name2) { UniqueUserEvents::EventRegistry::MEDICAL_RECORDS_ACCESSED }
  let(:oh_event_name) { UniqueUserEvents::EventRegistry::SECURE_MESSAGING_MESSAGE_SENT }

  describe '.buffer_events' do
    before do
      allow(UniqueUserEvents::EventRegistry).to receive(:validate_event!)
      allow(UniqueUserEvents::OracleHealth).to receive(:generate_events).and_return([])
      allow(UniqueUserEvents::Buffer).to receive(:push_batch)
    end

    context 'without event_facility_ids (user-based OH detection)' do
      it 'validates, expands, and buffers events using user facilities' do
        result = described_class.buffer_events(user:, event_names: [event_name])

        expect(result).to eq([event_name])
        expect(UniqueUserEvents::EventRegistry).to have_received(:validate_event!).with(event_name)
        expect(UniqueUserEvents::OracleHealth).to have_received(:generate_events)
          .with(user:, event_name:, event_facility_ids: nil)
        expect(UniqueUserEvents::Buffer).to have_received(:push_batch).with(
          [{ user_id:, event_name: }]
        )
      end

      it 'handles multiple events' do
        result = described_class.buffer_events(user:, event_names: [event_name, event_name2])

        expect(result).to eq([event_name, event_name2])
        expect(UniqueUserEvents::Buffer).to have_received(:push_batch).with(
          [
            { user_id:, event_name: },
            { user_id:, event_name: event_name2 }
          ]
        )
      end

      it 'includes Oracle Health events when applicable' do
        oh_events = ['mhv_sm_message_sent_oh_site_757']
        allow(UniqueUserEvents::OracleHealth).to receive(:generate_events)
          .with(user:, event_name: oh_event_name, event_facility_ids: nil)
          .and_return(oh_events)

        result = described_class.buffer_events(user:, event_names: [oh_event_name])

        expect(result).to eq([oh_event_name, 'mhv_sm_message_sent_oh_site_757'])
        expect(UniqueUserEvents::Buffer).to have_received(:push_batch).with(
          [
            { user_id:, event_name: oh_event_name },
            { user_id:, event_name: 'mhv_sm_message_sent_oh_site_757' }
          ]
        )
      end

      it 'handles empty event_names array' do
        result = described_class.buffer_events(user:, event_names: [])

        expect(result).to eq([])
        expect(UniqueUserEvents::Buffer).to have_received(:push_batch).with([])
      end

      it 'raises ArgumentError for invalid events' do
        allow(UniqueUserEvents::EventRegistry).to receive(:validate_event!)
          .and_raise(ArgumentError, 'Invalid event')

        expect do
          described_class.buffer_events(user:, event_names: ['invalid_event'])
        end.to raise_error(ArgumentError, 'Invalid event')
      end

      it 'uses user_account_uuid for user_id' do
        described_class.buffer_events(user:, event_names: [event_name])

        expect(UniqueUserEvents::Buffer).to have_received(:push_batch).with(
          [{ user_id: user.user_account_uuid, event_name: }]
        )
      end

      it 'falls back to uuid when user_account_uuid is nil' do
        user_without_account_uuid = double('User', user_account_uuid: nil, uuid: 'fallback-uuid', vha_facility_ids: [])

        described_class.buffer_events(user: user_without_account_uuid, event_names: [event_name])

        expect(UniqueUserEvents::Buffer).to have_received(:push_batch).with(
          [{ user_id: 'fallback-uuid', event_name: }]
        )
      end
    end

    context 'with event_facility_ids (explicit facility IDs)' do
      let(:event_facility_ids) { %w[757 688] }

      it 'validates, expands with facility IDs, and buffers events' do
        result = described_class.buffer_events(user:, event_names: [event_name], event_facility_ids:)

        expect(result).to eq([event_name])
        expect(UniqueUserEvents::EventRegistry).to have_received(:validate_event!).with(event_name)
        expect(UniqueUserEvents::OracleHealth).to have_received(:generate_events)
          .with(user:, event_name:, event_facility_ids:)
        expect(UniqueUserEvents::Buffer).to have_received(:push_batch).with(
          [{ user_id:, event_name: }]
        )
      end

      it 'includes site events when facility matches' do
        site_event = "#{event_name}_oh_757"
        allow(UniqueUserEvents::OracleHealth).to receive(:generate_events)
          .with(user:, event_name:, event_facility_ids:)
          .and_return([site_event])

        result = described_class.buffer_events(user:, event_names: [event_name], event_facility_ids:)

        expect(result).to eq([event_name, site_event])
        expect(UniqueUserEvents::Buffer).to have_received(:push_batch).with(
          [
            { user_id:, event_name: },
            { user_id:, event_name: site_event }
          ]
        )
      end

      it 'handles multiple events' do
        result = described_class.buffer_events(user:, event_names: [event_name, event_name2], event_facility_ids:)

        expect(result).to eq([event_name, event_name2])
        expect(UniqueUserEvents::OracleHealth).to have_received(:generate_events).twice
      end

      context 'with empty facility IDs' do
        let(:event_facility_ids) { [] }

        it 'still buffers the base event' do
          result = described_class.buffer_events(user:, event_names: [event_name], event_facility_ids:)

          expect(result).to eq([event_name])
          expect(UniqueUserEvents::OracleHealth).to have_received(:generate_events)
            .with(user:, event_name:, event_facility_ids: [])
          expect(UniqueUserEvents::Buffer).to have_received(:push_batch).with(
            [{ user_id:, event_name: }]
          )
        end
      end

      context 'with no matching facilities' do
        let(:event_facility_ids) { %w[999 888] }

        it 'only buffers the base event without OH events' do
          allow(UniqueUserEvents::OracleHealth).to receive(:generate_events).and_return([])

          result = described_class.buffer_events(user:, event_names: [event_name], event_facility_ids:)

          expect(result).to eq([event_name])
          expect(UniqueUserEvents::Buffer).to have_received(:push_batch).with(
            [{ user_id:, event_name: }]
          )
        end
      end

      it 'raises ArgumentError for invalid events' do
        allow(UniqueUserEvents::EventRegistry).to receive(:validate_event!)
          .and_raise(ArgumentError, 'Invalid event')

        expect do
          described_class.buffer_events(user:, event_names: ['invalid_event'], event_facility_ids:)
        end.to raise_error(ArgumentError, 'Invalid event')
      end
    end
  end

  describe '.event_logged?' do
    before do
      allow(Rails.logger).to receive(:error)
      allow(MHVMetricsUniqueUserEvent).to receive(:event_exists?)
    end

    it 'delegates to model and returns result' do
      allow(MHVMetricsUniqueUserEvent).to receive(:event_exists?).and_return(true)

      result = described_class.event_logged?(user:, event_name:)

      expect(result).to be(true)
      expect(MHVMetricsUniqueUserEvent).to have_received(:event_exists?).with(user_id:, event_name:)
    end

    it 'returns false when model returns false' do
      allow(MHVMetricsUniqueUserEvent).to receive(:event_exists?).and_return(false)

      result = described_class.event_logged?(user:, event_name:)

      expect(result).to be(false)
    end

    context 'when an exception occurs' do
      let(:error_message) { 'Database error' }

      before do
        allow(MHVMetricsUniqueUserEvent).to receive(:event_exists?).and_raise(StandardError, error_message)
      end

      it 'returns false and logs error without raising' do
        result = described_class.event_logged?(user:, event_name:)

        expect(result).to be(false)
        expect(Rails.logger).to have_received(:error)
          .with('UUM: Failed to check event', { user_id:, event_name:, error: error_message })
      end
    end

    context 'when event name is invalid' do
      let(:invalid_event_name) { 'invalid_unregistered_event' }

      it 'raises ArgumentError' do
        expect do
          described_class.event_logged?(user:, event_name: invalid_event_name)
        end.to raise_error(ArgumentError, /Invalid event name/)
      end
    end
  end
end
