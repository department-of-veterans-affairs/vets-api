# frozen_string_literal: true

require 'rails_helper'
require 'unique_user_events'

RSpec.describe UniqueUserEvents do
  let(:user) { double('User', user_account_uuid: SecureRandom.uuid) }
  let(:event_name) { UniqueUserEvents::EventRegistry::PRESCRIPTIONS_ACCESSED }

  describe '.log_event' do
    before do
      allow(Flipper).to receive(:enabled?).with(:unique_user_metrics_logging).and_return(true)
      allow(UniqueUserEvents::Service).to receive(:buffer_events).and_return([event_name])
      allow(StatsD).to receive(:measure)
    end

    it 'buffers event via Service and returns event names' do
      result = described_class.log_event(user:, event_name:)

      expect(result).to eq([event_name])
      expect(UniqueUserEvents::Service).to have_received(:buffer_events).with(
        user:, event_names: [event_name], event_facility_ids: nil
      )
    end

    context 'with event_facility_ids' do
      let(:event_facility_ids) { %w[757 688] }

      it 'passes facility IDs to Service' do
        result = described_class.log_event(user:, event_name:, event_facility_ids:)

        expect(result).to eq([event_name])
        expect(UniqueUserEvents::Service).to have_received(:buffer_events).with(
          user:, event_names: [event_name], event_facility_ids:
        )
      end
    end

    context 'when feature flag is disabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:unique_user_metrics_logging).and_return(false)
      end

      it 'returns empty array without buffering' do
        result = described_class.log_event(user:, event_name:)

        expect(result).to eq([])
        expect(UniqueUserEvents::Service).not_to have_received(:buffer_events)
      end

      it 'does not measure performance metrics when disabled' do
        expect(StatsD).not_to receive(:measure)

        described_class.log_event(user:, event_name:)
      end
    end

    context 'when ArgumentError is raised' do
      before do
        allow(UniqueUserEvents::Service).to receive(:buffer_events).and_raise(ArgumentError, 'Invalid event')
      end

      it 're-raises the error' do
        expect { described_class.log_event(user:, event_name:) }.to raise_error(ArgumentError, 'Invalid event')
      end
    end

    context 'when other errors occur' do
      before do
        allow(UniqueUserEvents::Service).to receive(:buffer_events).and_raise(StandardError, 'Service error')
        allow(Rails.logger).to receive(:error)
      end

      it 'returns empty array' do
        result = described_class.log_event(user:, event_name:)

        expect(result).to eq([])
      end

      it 'logs the error' do
        described_class.log_event(user:, event_name:)

        expect(Rails.logger).to have_received(:error).with(/UUM: Failed during log_events/)
      end
    end
  end

  describe '.log_events' do
    let(:event_name2) { UniqueUserEvents::EventRegistry::MEDICAL_RECORDS_ACCESSED }

    before do
      allow(Flipper).to receive(:enabled?).with(:unique_user_metrics_logging).and_return(true)
      allow(UniqueUserEvents::Service).to receive(:buffer_events).and_return([event_name, event_name2])
      allow(StatsD).to receive(:measure)
    end

    it 'buffers multiple events and returns all event names' do
      result = described_class.log_events(user:, event_names: [event_name, event_name2])

      expect(result).to eq([event_name, event_name2])
      expect(UniqueUserEvents::Service).to have_received(:buffer_events)
        .with(user:, event_names: [event_name, event_name2], event_facility_ids: nil)
    end

    it 'handles empty array' do
      allow(UniqueUserEvents::Service).to receive(:buffer_events).and_return([])

      result = described_class.log_events(user:, event_names: [])

      expect(result).to eq([])
    end

    it 'measures duration' do
      described_class.log_events(user:, event_names: [event_name])

      expect(StatsD).to have_received(:measure).with('uum.unique_user_metrics.log_events.duration', kind_of(Numeric))
    end

    context 'with event_facility_ids' do
      let(:event_facility_ids) { %w[757 688] }

      it 'passes facility IDs to Service' do
        result = described_class.log_events(user:, event_names: [event_name, event_name2], event_facility_ids:)

        expect(result).to eq([event_name, event_name2])
        expect(UniqueUserEvents::Service).to have_received(:buffer_events)
          .with(user:, event_names: [event_name, event_name2], event_facility_ids:)
      end
    end

    context 'when feature flag is disabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:unique_user_metrics_logging).and_return(false)
      end

      it 'returns empty array without buffering' do
        result = described_class.log_events(user:, event_names: [event_name])

        expect(result).to eq([])
        expect(UniqueUserEvents::Service).not_to have_received(:buffer_events)
      end
    end

    context 'when ArgumentError is raised' do
      before do
        allow(UniqueUserEvents::Service).to receive(:buffer_events).and_raise(ArgumentError, 'Invalid event')
      end

      it 're-raises the error' do
        expect do
          described_class.log_events(user:, event_names: [event_name])
        end.to raise_error(ArgumentError, 'Invalid event')
      end
    end

    context 'when other errors occur' do
      before do
        allow(UniqueUserEvents::Service).to receive(:buffer_events).and_raise(StandardError, 'Service error')
        allow(Rails.logger).to receive(:error)
      end

      it 'returns empty array and logs the error' do
        result = described_class.log_events(user:, event_names: [event_name])

        expect(result).to eq([])
        expect(Rails.logger).to have_received(:error).with(/UUM: Failed during log_events/)
      end
    end

    context 'with empty facility IDs' do
      let(:event_facility_ids) { [] }

      it 'still calls Service with empty array' do
        described_class.log_events(user:, event_names: [event_name], event_facility_ids:)

        expect(UniqueUserEvents::Service).to have_received(:buffer_events).with(
          user:, event_names: [event_name], event_facility_ids: []
        )
      end
    end

    context 'with nil-containing facility IDs after compacting' do
      let(:event_facility_ids) { %w[757] }

      it 'handles facility IDs correctly' do
        allow(UniqueUserEvents::Service).to receive(:buffer_events)
          .and_return([event_name, "#{event_name}_oh_site_757"])

        result = described_class.log_events(user:, event_names: [event_name], event_facility_ids:)

        expect(result).to include("#{event_name}_oh_site_757")
      end
    end
  end

  describe '.event_logged?' do
    before do
      allow(UniqueUserEvents::Service).to receive(:event_logged?)
    end

    it 'delegates to service and returns result' do
      allow(UniqueUserEvents::Service).to receive(:event_logged?).and_return(true)

      result = described_class.event_logged?(user:, event_name:)

      expect(result).to be(true)
      expect(UniqueUserEvents::Service).to have_received(:event_logged?).with(user:, event_name:)
    end

    it 'passes through service result when false' do
      allow(UniqueUserEvents::Service).to receive(:event_logged?).and_return(false)

      result = described_class.event_logged?(user:, event_name:)

      expect(result).to be(false)
    end
  end
end
