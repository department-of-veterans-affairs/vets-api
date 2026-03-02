# frozen_string_literal: true

require 'medical_records/medical_records_log'

module UnifiedHealthData
  module Concerns
    # Logging and metrics for labs and tests. Follows ClinicalNotesLogging pattern.
    # See MedicalRecords::MedicalRecordsLog "Adding a New Domain" guide.
    #
    # Stub Flipper in tests (never use Flipper.enable/disable):
    #   allow(Flipper).to receive(:enabled?).with(:mhv_medical_records_labs_and_tests_diagnostic, user).and_return(true)
    module LabsAndTestsLogging # rubocop:disable Metrics/ModuleLength
      extend ActiveSupport::Concern

      LABS = MedicalRecords::MedicalRecordsLog::LABS_AND_TESTS
      HIGH_FILTER_RATE_THRESHOLD = 0.5
      MISSING_DATE_THRESHOLD = 3
      EMPTY_OBSERVATIONS_THRESHOLD = 3

      private

      def mr_log
        @mr_log ||= MedicalRecords::MedicalRecordsLog.new(user: @user)
      end

      def labs_logging_enabled?
        mr_log.diagnostic_enabled?(LABS)
      end

      def labs_statsd_prefix
        "#{self.class::STATSD_KEY_PREFIX}.labs_and_tests"
      end

      # StatsD tags array including caller when present.
      def labs_statsd_tags
        @labs_caller ? ["caller:#{@labs_caller}"] : []
      end

      # Base metadata included in every structured log entry.
      def labs_caller_metadata
        @labs_caller ? { caller: @labs_caller } : {}
      end

      # Logs test code and display name distribution (migrated from Logging class).
      def log_test_code_distribution(records)
        return unless labs_logging_enabled?

        code_counts, name_counts, short_name_count = count_test_codes(records)
        return if code_counts.empty? && name_counts.empty?

        emit_distribution_diagnostic(code_counts, name_counts, records.size)
        warn_short_test_names(short_name_count, records.size)
      end

      def count_test_codes(records)
        code_counts = Hash.new(0)
        name_counts = Hash.new(0)
        short_name_count = 0
        records.each do |record|
          code_counts[record.test_code] += 1 if record.test_code.present?
          if record.display.present?
            name_counts[record.display] += 1
            short_name_count += 1 if record.display.length <= 3
          end
        end
        [code_counts, name_counts, short_name_count]
      end

      def emit_distribution_diagnostic(code_counts, name_counts, total_records)
        sorted_codes = code_counts.sort_by { |_, c| -c }
        sorted_names = name_counts.sort_by { |_, c| -c }
        mr_log.diagnostic(
          resource: LABS, action: 'test_code_distribution',
          test_code_distribution: sorted_codes.map { |code, c| "#{code}:#{c}" }.join(','),
          test_name_distribution: sorted_names.map { |name, c| "#{name}:#{c}" }.join(','),
          total_codes: sorted_codes.size, total_names: sorted_names.size, total_records:,
          **labs_caller_metadata
        )
        StatsD.gauge("#{labs_statsd_prefix}.diagnostic.test_code_count", sorted_codes.size, tags: labs_statsd_tags)
      end

      def log_labs_response_count(raw_count, parsed_count)
        mr_log.diagnostic(
          resource: LABS, action: 'filter',
          total_entries: raw_count, returned: parsed_count, filtered: raw_count - parsed_count,
          **labs_caller_metadata
        )
      end

      def log_labs_index_metrics(parsed_labs, start_date, end_date)
        total = parsed_labs.size
        vista_count = parsed_labs.count { |l| l.source == SourceConstants::VISTA }
        oh_count = parsed_labs.count { |l| l.source == SourceConstants::ORACLE_HEALTH }
        total_obs = parsed_labs.sum { |l| l.observations.size }
        mr_log.diagnostic(
          resource: LABS, action: 'index', total_labs: total, vista_count:,
          oracle_health_count: oh_count, total_observations: total_obs,
          avg_observations_per_report: total.positive? ? (total_obs.to_f / total).round(1) : 0,
          start_date:, end_date:, **labs_caller_metadata
        )
        StatsD.gauge("#{labs_statsd_prefix}.index.total", total, tags: labs_statsd_tags)
        StatsD.gauge("#{labs_statsd_prefix}.index.vista", vista_count, tags: labs_statsd_tags)
        StatsD.gauge("#{labs_statsd_prefix}.index.oracle_health", oh_count, tags: labs_statsd_tags)
      end

      # Shared helper for always-on anomaly warnings: logs + increments StatsD.
      def emit_anomaly(action:, anomaly:, **metadata)
        mr_log.warn(resource: LABS, action:, anomaly:, **metadata, **labs_caller_metadata)
        StatsD.increment("#{labs_statsd_prefix}.anomaly.#{anomaly}", tags: labs_statsd_tags)
      end

      # Warns when >50% of DiagnosticReports are dropped during parsing.
      def warn_labs_high_filter_rate(raw_count, parsed_count)
        return if raw_count.zero?

        filter_rate = 1.0 - (parsed_count.to_f / raw_count)
        return unless filter_rate > HIGH_FILTER_RATE_THRESHOLD

        emit_anomaly(action: 'index', anomaly: 'high_filter_rate',
                     filter_rate: (filter_rate * 100).round(1), raw_count:, parsed_count:)
      end

      def warn_missing_dates(missing_date_count, total_count)
        return unless missing_date_count >= MISSING_DATE_THRESHOLD

        emit_anomaly(action: 'parse', anomaly: 'elevated_missing_dates',
                     missing_count: missing_date_count, total_count:)
      end

      def warn_empty_observations(empty_count, total_count)
        return unless empty_count >= EMPTY_OBSERVATIONS_THRESHOLD

        emit_anomaly(action: 'parse', anomaly: 'elevated_empty_observations',
                     empty_count:, total_count:)
      end

      # Replaces PersonalInformationLog approach — no PII stored.
      def warn_short_test_names(short_name_count, total_count)
        return if short_name_count.zero?

        emit_anomaly(action: 'parse', anomaly: 'short_test_names',
                     short_name_count:, total_count:)
      end

      # Structured error log for get_labs failures — provides domain context for triage.
      def log_labs_error(error, start_date, end_date)
        mr_log.error(
          resource: LABS, action: 'index',
          error_class: error.class.name, error_message: error.message,
          start_date:, end_date:, **labs_caller_metadata
        )
        StatsD.increment("#{labs_statsd_prefix}.error", tags: labs_statsd_tags)
      end

      # Orchestrates index-level metrics and proactive warnings for get_labs.
      def log_labs_metrics(combined_records, parsed_labs, start_date, end_date)
        parsed_count = parsed_labs.size
        raw_count = combined_records.size

        labs_logging_enabled? && log_labs_response_count(raw_count, parsed_count)
        labs_logging_enabled? && log_labs_index_metrics(parsed_labs, start_date, end_date)
        warn_labs_high_filter_rate(raw_count, parsed_count)
        warn_missing_dates(parsed_labs.count { |l| l.date_completed.blank? }, parsed_count)
        warn_empty_observations(parsed_labs.count { |l| l.observations.empty? }, parsed_count)
      end
    end
  end
end
