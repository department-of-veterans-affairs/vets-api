# frozen_string_literal: true

require 'rails_helper'
require 'unified_health_data/concerns/clinical_notes_logging'
require 'unified_health_data/source_constants'

RSpec.describe UnifiedHealthData::Concerns::ClinicalNotesLogging do
  subject(:instance) { test_class.new(user) }

  let(:user) { build(:user, :loa3) }

  # Create a lightweight test class that includes the concern
  let(:test_class) do
    klass = Class.new do
      include UnifiedHealthData::Concerns::ClinicalNotesLogging

      def initialize(user)
        @user = user
      end
    end
    klass.const_set(:STATSD_KEY_PREFIX, 'api.uhd')
    klass
  end

  before do
    allow(Rails.logger).to receive(:info)
    allow(StatsD).to receive(:gauge)
    allow(StatsD).to receive(:increment)
  end

  describe '#log_loinc_codes_enabled?' do
    it 'returns true when the Flipper flag is enabled' do
      allow(Flipper).to receive(:enabled?)
        .with(:mhv_accelerated_delivery_uhd_loinc_logging_enabled, user)
        .and_return(true)

      expect(instance.send(:log_loinc_codes_enabled?)).to be true
    end

    it 'returns false when the Flipper flag is disabled' do
      allow(Flipper).to receive(:enabled?)
        .with(:mhv_accelerated_delivery_uhd_loinc_logging_enabled, user)
        .and_return(false)

      expect(instance.send(:log_loinc_codes_enabled?)).to be false
    end
  end

  describe '#clinical_notes_logging_enabled?' do
    it 'returns true when the Flipper flag is enabled' do
      allow(Flipper).to receive(:enabled?)
        .with(:mhv_accelerated_delivery_uhd_clinical_notes_logging_enabled, user)
        .and_return(true)

      expect(instance.send(:clinical_notes_logging_enabled?)).to be true
    end

    it 'returns false when the Flipper flag is disabled' do
      allow(Flipper).to receive(:enabled?)
        .with(:mhv_accelerated_delivery_uhd_clinical_notes_logging_enabled, user)
        .and_return(false)

      expect(instance.send(:clinical_notes_logging_enabled?)).to be false
    end
  end

  describe '#log_notes_response_count' do
    it 'logs the total, returned, and filtered counts' do
      instance.send(:log_notes_response_count, 10, 7)

      expect(Rails.logger).to have_received(:info).with(
        'Clinical Notes response: total_doc_refs=10, returned=7, filtered=3',
        { service: 'unified_health_data' }
      )
    end
  end

  describe '#log_notes_index_metrics' do
    let(:vista_note) { double('ClinicalNotes', source: 'vista') }
    let(:oh_note) { double('ClinicalNotes', source: 'oracle-health') }
    let(:parsed_notes) { [vista_note, vista_note, oh_note] }

    it 'logs the source breakdown' do
      instance.send(:log_notes_index_metrics, parsed_notes, '2024-01-01', '2025-06-01')

      expect(Rails.logger).to have_received(:info).with(
        hash_including(
          message: 'Clinical Notes index response',
          total_notes: 3,
          vista_count: 2,
          oracle_health_count: 1,
          start_date: '2024-01-01',
          end_date: '2025-06-01',
          service: 'unified_health_data'
        )
      )
    end

    it 'emits StatsD gauges for each source' do
      instance.send(:log_notes_index_metrics, parsed_notes, '2024-01-01', '2025-06-01')

      expect(StatsD).to have_received(:gauge).with('api.uhd.clinical_notes.index.total', 3)
      expect(StatsD).to have_received(:gauge).with('api.uhd.clinical_notes.index.vista', 2)
      expect(StatsD).to have_received(:gauge).with('api.uhd.clinical_notes.index.oracle_health', 1)
    end
  end

  describe '#log_notes_show_metrics' do
    context 'when note is found' do
      let(:result) { double('ClinicalNotes', note_type: 'progress_note', present?: true) }

      it 'logs with the provided source and note_found true' do
        instance.send(:log_notes_show_metrics, 'oracle-health', result)

        expect(Rails.logger).to have_received(:info).with(
          hash_including(
            message: 'Clinical Notes show request',
            source: 'oracle-health',
            note_found: true,
            note_type: 'progress_note',
            service: 'unified_health_data'
          )
        )
      end

      it 'emits StatsD increment with the source tag' do
        instance.send(:log_notes_show_metrics, 'oracle-health', result)

        expect(StatsD).to have_received(:increment)
          .with('api.uhd.clinical_notes.show.source', tags: ['source:oracle-health'])
      end

      it 'does not emit a not_found increment' do
        instance.send(:log_notes_show_metrics, 'oracle-health', result)

        expect(StatsD).not_to have_received(:increment)
          .with('api.uhd.clinical_notes.show.not_found')
      end
    end

    context 'when note is not found' do
      it 'logs with note_found false and nil note_type' do
        instance.send(:log_notes_show_metrics, 'vista', nil)

        expect(Rails.logger).to have_received(:info).with(
          hash_including(
            message: 'Clinical Notes show request',
            note_found: false,
            note_type: nil
          )
        )
      end

      it 'emits a not_found StatsD increment' do
        instance.send(:log_notes_show_metrics, 'vista', nil)

        expect(StatsD).to have_received(:increment)
          .with('api.uhd.clinical_notes.show.not_found')
      end
    end

    context 'when source is nil (vista fallback)' do
      let(:result) { double('ClinicalNotes', note_type: 'discharge_summary', present?: true) }

      it 'defaults source to vista_fallback' do
        instance.send(:log_notes_show_metrics, nil, result)

        expect(Rails.logger).to have_received(:info).with(
          hash_including(source: 'vista_fallback')
        )
        expect(StatsD).to have_received(:increment)
          .with('api.uhd.clinical_notes.show.source', tags: ['source:vista_fallback'])
      end
    end
  end
end
