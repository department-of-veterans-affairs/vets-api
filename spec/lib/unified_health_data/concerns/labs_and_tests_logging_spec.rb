# frozen_string_literal: true

require 'rails_helper'
require 'unified_health_data/concerns/labs_and_tests_logging'
require 'unified_health_data/source_constants'
require 'medical_records/medical_records_log'

RSpec.describe UnifiedHealthData::Concerns::LabsAndTestsLogging do
  subject(:instance) { test_class.new(user) }

  let(:user) { build(:user, :loa3) }

  # Create a lightweight test class that includes the concern
  let(:test_class) do
    klass = Class.new do
      include UnifiedHealthData::Concerns::LabsAndTestsLogging

      def initialize(user)
        @user = user
      end
    end
    klass.const_set(:STATSD_KEY_PREFIX, 'api.uhd')
    klass
  end

  before do
    allow(Rails.logger).to receive(:info)
    allow(Rails.logger).to receive(:warn)
    allow(StatsD).to receive(:gauge)
    allow(StatsD).to receive(:increment)
  end

  describe '#labs_logging_enabled?' do
    it 'returns true when the domain toggle is enabled' do
      allow(Flipper).to receive(:enabled?)
        .with(:mhv_medical_records_labs_and_tests_diagnostic, user)
        .and_return(true)

      expect(instance.send(:labs_logging_enabled?)).to be true
    end

    it 'returns true when the global toggle is enabled as fallback' do
      allow(Flipper).to receive(:enabled?)
        .with(:mhv_medical_records_labs_and_tests_diagnostic, user)
        .and_return(false)
      allow(Flipper).to receive(:enabled?)
        .with(:mhv_medical_records_diagnostic_logging, user)
        .and_return(true)

      expect(instance.send(:labs_logging_enabled?)).to be true
    end

    it 'returns false when both toggles are disabled' do
      allow(Flipper).to receive(:enabled?)
        .with(:mhv_medical_records_labs_and_tests_diagnostic, user)
        .and_return(false)
      allow(Flipper).to receive(:enabled?)
        .with(:mhv_medical_records_diagnostic_logging, user)
        .and_return(false)

      expect(instance.send(:labs_logging_enabled?)).to be false
    end
  end

  describe '#log_test_code_distribution' do
    let(:record1) { double('LabOrTest', test_code: 'CBC', display: 'Complete Blood Count') }
    let(:record2) { double('LabOrTest', test_code: 'CBC', display: 'Complete Blood Count') }
    let(:record3) { double('LabOrTest', test_code: 'BMP', display: 'Basic Metabolic Panel') }
    let(:records) { [record1, record2, record3] }

    before do
      allow(Flipper).to receive(:enabled?)
        .with(:mhv_medical_records_labs_and_tests_diagnostic, user)
        .and_return(true)
    end

    it 'logs test code and name distribution via MedicalRecordsLog' do
      instance.send(:log_test_code_distribution, records)

      expect(Rails.logger).to have_received(:info).with(
        hash_including(
          service: 'medical_records',
          resource: 'labs_and_tests',
          action: 'test_code_distribution',
          total_codes: 2,
          total_names: 2,
          total_records: 3,
          log_level_context: 'diagnostic'
        )
      )
    end

    it 'includes formatted distribution strings' do
      instance.send(:log_test_code_distribution, records)

      expect(Rails.logger).to have_received(:info).with(
        hash_including(
          test_code_distribution: 'CBC:2,BMP:1',
          test_name_distribution: 'Complete Blood Count:2,Basic Metabolic Panel:1'
        )
      )
    end

    it 'emits a StatsD gauge for test code count' do
      instance.send(:log_test_code_distribution, records)

      expect(StatsD).to have_received(:gauge)
        .with('api.uhd.labs_and_tests.diagnostic.test_code_count', 2)
    end

    it 'does not log when all test codes and names are blank' do
      empty_records = [double('LabOrTest', test_code: nil, display: nil)]

      instance.send(:log_test_code_distribution, empty_records)

      expect(Rails.logger).not_to have_received(:info)
    end

    it 'does not log when logging is disabled' do
      allow(Flipper).to receive(:enabled?)
        .with(:mhv_medical_records_labs_and_tests_diagnostic, user)
        .and_return(false)
      allow(Flipper).to receive(:enabled?)
        .with(:mhv_medical_records_diagnostic_logging, user)
        .and_return(false)

      instance.send(:log_test_code_distribution, records)

      expect(Rails.logger).not_to have_received(:info)
    end

    it 'triggers warn_short_test_names when short names are present' do
      short_record = double('LabOrTest', test_code: 'X', display: 'AB')
      instance.send(:log_test_code_distribution, [short_record])

      expect(Rails.logger).to have_received(:warn).with(
        hash_including(
          resource: 'labs_and_tests',
          anomaly: 'short_test_names',
          short_name_count: 1
        )
      )
    end
  end

  describe '#log_labs_response_count' do
    before do
      allow(Flipper).to receive(:enabled?)
        .with(:mhv_medical_records_labs_and_tests_diagnostic, user)
        .and_return(true)
    end

    it 'logs the total, returned, and filtered counts via MedicalRecordsLog' do
      instance.send(:log_labs_response_count, 10, 7)

      expect(Rails.logger).to have_received(:info).with(
        hash_including(
          service: 'medical_records',
          resource: 'labs_and_tests',
          action: 'filter',
          total_entries: 10,
          returned: 7,
          filtered: 3,
          log_level_context: 'diagnostic'
        )
      )
    end
  end

  describe '#log_labs_index_metrics' do
    let(:obs1) { double('Observation') }
    let(:obs2) { double('Observation') }
    let(:vista_lab) { double('LabOrTest', source: 'vista', observations: [obs1, obs2]) }
    let(:oh_lab) { double('LabOrTest', source: 'oracle-health', observations: [obs1]) }
    let(:parsed_labs) { [vista_lab, vista_lab, oh_lab] }

    before do
      allow(Flipper).to receive(:enabled?)
        .with(:mhv_medical_records_labs_and_tests_diagnostic, user)
        .and_return(true)
    end

    it 'logs the source breakdown and observation stats via MedicalRecordsLog' do
      instance.send(:log_labs_index_metrics, parsed_labs, '2024-01-01', '2025-06-01')

      expect(Rails.logger).to have_received(:info).with(
        hash_including(
          service: 'medical_records',
          resource: 'labs_and_tests',
          action: 'index',
          total_labs: 3,
          vista_count: 2,
          oracle_health_count: 1,
          total_observations: 5,
          avg_observations_per_report: 1.7,
          start_date: '2024-01-01',
          end_date: '2025-06-01',
          log_level_context: 'diagnostic'
        )
      )
    end

    it 'emits StatsD gauges for each source' do
      instance.send(:log_labs_index_metrics, parsed_labs, '2024-01-01', '2025-06-01')

      expect(StatsD).to have_received(:gauge).with('api.uhd.labs_and_tests.index.total', 3)
      expect(StatsD).to have_received(:gauge).with('api.uhd.labs_and_tests.index.vista', 2)
      expect(StatsD).to have_received(:gauge).with('api.uhd.labs_and_tests.index.oracle_health', 1)
    end

    it 'handles empty labs array gracefully' do
      instance.send(:log_labs_index_metrics, [], '2024-01-01', '2025-06-01')

      expect(Rails.logger).to have_received(:info).with(
        hash_including(
          total_labs: 0,
          total_observations: 0,
          avg_observations_per_report: 0
        )
      )
    end
  end

  describe '#warn_labs_high_filter_rate' do
    it 'warns when more than 50% of entries are filtered' do
      instance.send(:warn_labs_high_filter_rate, 10, 4)

      expect(Rails.logger).to have_received(:warn).with(
        hash_including(
          service: 'medical_records',
          resource: 'labs_and_tests',
          action: 'index',
          anomaly: 'high_filter_rate',
          filter_rate: 60.0,
          raw_count: 10,
          parsed_count: 4
        )
      )
    end

    it 'emits a StatsD increment for the anomaly' do
      instance.send(:warn_labs_high_filter_rate, 10, 4)

      expect(StatsD).to have_received(:increment)
        .with('api.uhd.labs_and_tests.anomaly.high_filter_rate')
    end

    it 'does not warn when filter rate is at or below 50%' do
      instance.send(:warn_labs_high_filter_rate, 10, 5)

      expect(Rails.logger).not_to have_received(:warn)
      expect(StatsD).not_to have_received(:increment)
        .with('api.uhd.labs_and_tests.anomaly.high_filter_rate')
    end

    it 'does not warn when raw_count is zero' do
      instance.send(:warn_labs_high_filter_rate, 0, 0)

      expect(Rails.logger).not_to have_received(:warn)
    end
  end

  describe '#warn_missing_dates' do
    it 'warns when missing date count meets the threshold' do
      instance.send(:warn_missing_dates, 3, 20)

      expect(Rails.logger).to have_received(:warn).with(
        hash_including(
          service: 'medical_records',
          resource: 'labs_and_tests',
          action: 'parse',
          anomaly: 'elevated_missing_dates',
          missing_count: 3,
          total_count: 20
        )
      )
    end

    it 'emits a StatsD increment for the anomaly' do
      instance.send(:warn_missing_dates, 3, 20)

      expect(StatsD).to have_received(:increment)
        .with('api.uhd.labs_and_tests.anomaly.elevated_missing_dates')
    end

    it 'does not warn when missing date count is below the threshold' do
      instance.send(:warn_missing_dates, 2, 20)

      expect(Rails.logger).not_to have_received(:warn)
      expect(StatsD).not_to have_received(:increment)
        .with('api.uhd.labs_and_tests.anomaly.elevated_missing_dates')
    end
  end

  describe '#warn_empty_observations' do
    it 'warns when empty observation count meets the threshold' do
      instance.send(:warn_empty_observations, 3, 15)

      expect(Rails.logger).to have_received(:warn).with(
        hash_including(
          service: 'medical_records',
          resource: 'labs_and_tests',
          action: 'parse',
          anomaly: 'elevated_empty_observations',
          empty_count: 3,
          total_count: 15
        )
      )
    end

    it 'emits a StatsD increment for the anomaly' do
      instance.send(:warn_empty_observations, 3, 15)

      expect(StatsD).to have_received(:increment)
        .with('api.uhd.labs_and_tests.anomaly.elevated_empty_observations')
    end

    it 'does not warn when empty count is below the threshold' do
      instance.send(:warn_empty_observations, 2, 15)

      expect(Rails.logger).not_to have_received(:warn)
      expect(StatsD).not_to have_received(:increment)
        .with('api.uhd.labs_and_tests.anomaly.elevated_empty_observations')
    end
  end

  describe '#warn_short_test_names' do
    it 'warns when short name count is greater than zero' do
      instance.send(:warn_short_test_names, 2, 10)

      expect(Rails.logger).to have_received(:warn).with(
        hash_including(
          service: 'medical_records',
          resource: 'labs_and_tests',
          action: 'parse',
          anomaly: 'short_test_names',
          short_name_count: 2,
          total_count: 10
        )
      )
    end

    it 'emits a StatsD increment for the anomaly' do
      instance.send(:warn_short_test_names, 2, 10)

      expect(StatsD).to have_received(:increment)
        .with('api.uhd.labs_and_tests.anomaly.short_test_names')
    end

    it 'does not warn when short name count is zero' do
      instance.send(:warn_short_test_names, 0, 10)

      expect(Rails.logger).not_to have_received(:warn)
      expect(StatsD).not_to have_received(:increment)
        .with('api.uhd.labs_and_tests.anomaly.short_test_names')
    end
  end

  describe '#log_labs_metrics' do
    let(:obs) { double('Observation') }
    let(:vista_lab) { double('LabOrTest', source: 'vista', observations: [obs], date_completed: '2024-06-01') }
    let(:oh_lab) do
      double('LabOrTest', source: 'oracle-health', observations: [obs, obs], date_completed: '2024-07-01')
    end
    let(:parsed_labs) { [vista_lab, oh_lab] }

    # combined_records simulates unfiltered FHIR entries (4 total, 2 survived parsing)
    let(:combined_records) { [double, double, double, double] }

    context 'when logging is enabled' do
      before do
        allow(Flipper).to receive(:enabled?)
          .with(:mhv_medical_records_labs_and_tests_diagnostic, user)
          .and_return(true)
      end

      it 'logs response count, index metrics, and high filter rate warning' do
        instance.send(:log_labs_metrics, combined_records, parsed_labs, '2024-01-01', '2025-06-01')

        # Diagnostic: filter counts
        expect(Rails.logger).to have_received(:info).with(
          hash_including(action: 'filter', total_entries: 4, returned: 2, filtered: 2)
        )

        # Diagnostic: index metrics
        expect(Rails.logger).to have_received(:info).with(
          hash_including(action: 'index', total_labs: 2, vista_count: 1, oracle_health_count: 1)
        )

        # Always-on: high filter rate warning (50% > threshold)
        # 50% is not > 50%, so NO warn expected for exactly 50%
        expect(Rails.logger).not_to have_received(:warn)
      end

      it 'triggers high filter rate warning when rate exceeds threshold' do
        # 5 raw, 2 parsed = 60% filtered
        big_combined = Array.new(5) { double }
        instance.send(:log_labs_metrics, big_combined, parsed_labs, '2024-01-01', '2025-06-01')

        expect(Rails.logger).to have_received(:warn).with(
          hash_including(anomaly: 'high_filter_rate', filter_rate: 60.0)
        )
      end

      it 'triggers missing dates warning when threshold met' do
        missing_date_labs = Array.new(3) do
          double('LabOrTest', source: 'vista', observations: [obs], date_completed: nil)
        end
        instance.send(:log_labs_metrics, combined_records, missing_date_labs, '2024-01-01', '2025-06-01')

        expect(Rails.logger).to have_received(:warn).with(
          hash_including(anomaly: 'elevated_missing_dates', missing_count: 3, total_count: 3)
        )
      end

      it 'triggers empty observations warning when threshold met' do
        empty_obs_labs = Array.new(3) do
          double('LabOrTest', source: 'vista', observations: [], date_completed: '2024-06-01')
        end
        instance.send(:log_labs_metrics, combined_records, empty_obs_labs, '2024-01-01', '2025-06-01')

        expect(Rails.logger).to have_received(:warn).with(
          hash_including(anomaly: 'elevated_empty_observations', empty_count: 3, total_count: 3)
        )
      end
    end

    context 'when logging is disabled' do
      before do
        allow(Flipper).to receive(:enabled?)
          .with(:mhv_medical_records_labs_and_tests_diagnostic, user)
          .and_return(false)
        allow(Flipper).to receive(:enabled?)
          .with(:mhv_medical_records_diagnostic_logging, user)
          .and_return(false)
      end

      it 'skips diagnostic logs but still emits always-on warnings' do
        # 5 raw, 2 parsed = 60% filtered – always-on warning should fire
        big_combined = Array.new(5) { double }
        instance.send(:log_labs_metrics, big_combined, parsed_labs, '2024-01-01', '2025-06-01')

        expect(Rails.logger).not_to have_received(:info)
          .with(hash_including(action: 'filter'))
        expect(Rails.logger).to have_received(:warn).with(
          hash_including(anomaly: 'high_filter_rate')
        )
      end

      it 'still emits missing dates and empty observations warnings when disabled' do
        missing_and_empty = Array.new(3) do
          double('LabOrTest', source: 'vista', observations: [], date_completed: nil)
        end
        instance.send(:log_labs_metrics, combined_records, missing_and_empty, '2024-01-01', '2025-06-01')

        expect(Rails.logger).to have_received(:warn).with(
          hash_including(anomaly: 'elevated_missing_dates')
        )
        expect(Rails.logger).to have_received(:warn).with(
          hash_including(anomaly: 'elevated_empty_observations')
        )
      end
    end
  end
end
