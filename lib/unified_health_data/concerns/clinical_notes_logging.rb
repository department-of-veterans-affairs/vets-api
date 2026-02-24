# frozen_string_literal: true

require 'medical_records/medical_records_log'

module UnifiedHealthData
  module Concerns
    # Logging and metrics methods for clinical notes operations.
    # Extracted from Service to keep class length manageable.
    #
    # == Reference Implementation
    #
    # This concern is the canonical example of the MedicalRecordsLog pattern.
    # Use it as a template when adding logging for a new domain (allergies, vitals, etc.).
    # See MedicalRecords::MedicalRecordsLog class docs for the full "Adding a New Domain" guide.
    #
    # == Pattern Summary
    #
    # 1. Memoize an MedicalRecordsLog instance via +mr_log+ (receives +@user+ from the host class).
    # 2. Wrap each log point in a small descriptive method (e.g. +log_notes_index_metrics+).
    # 3. Use +mr_log.diagnostic+ for verbose data that should only appear when a Flipper toggle
    #    is enabled for the user. Use +mr_log.info/warn/error+ for always-on operational data.
    # 4. Guard expensive pre-computation with +return unless clinical_notes_logging_enabled?+
    #    so disabled toggles skip the work entirely (see +log_loinc_code_distribution+).
    # 5. Keep StatsD instrumentation alongside the log calls — they serve different consumers
    #    (DataDog dashboards vs. Splunk/CloudWatch log queries).
    #
    # == Toggle Behavior
    #
    # Delegates toggle checks to MedicalRecords::MedicalRecordsLog, which provides the
    # +:mhv_medical_records_clinical_notes_diagnostic+ domain toggle with a global fallback
    # via +:mhv_medical_records_diagnostic_logging+. Enabling either toggle activates
    # diagnostic logging for clinical notes.
    #
    # == Specs
    #
    # Stub Flipper (never use Flipper.enable/disable in tests):
    #   allow(Flipper).to receive(:enabled?).with(:mhv_medical_records_clinical_notes_diagnostic, user).and_return(true)
    #
    # Assert on the structured hash:
    #   expect(Rails.logger).to have_received(:info).with(hash_including(service: 'medical_records', ...))
    module ClinicalNotesLogging
      extend ActiveSupport::Concern

      private

      def mr_log
        @mr_log ||= MedicalRecords::MedicalRecordsLog.new(user: @user)
      end

      def clinical_notes_logging_enabled?
        mr_log.diagnostic_enabled?(MedicalRecords::MedicalRecordsLog::CLINICAL_NOTES)
      end

      def log_loinc_code_distribution(records, record_type = 'Clinical Notes')
        return unless clinical_notes_logging_enabled?

        loinc_code_counts = Hash.new(0)

        records.each do |record|
          loinc_codes = record.loinc_codes
          loinc_codes.each { |code| loinc_code_counts[code] += 1 if code.present? }
        end

        return if loinc_code_counts.empty?

        sorted_code_counts = loinc_code_counts.sort_by { |_, count| -count }
        code_count_pairs = sorted_code_counts.map { |code, count| "#{code}:#{count}" }

        mr_log.diagnostic(
          resource: MedicalRecords::MedicalRecordsLog::CLINICAL_NOTES,
          action: 'loinc_distribution',
          record_type:,
          loinc_code_distribution: code_count_pairs.join(','),
          total_codes: sorted_code_counts.size,
          total_records: records.size
        )
      end

      def log_notes_response_count(total, returned)
        mr_log.diagnostic(
          resource: MedicalRecords::MedicalRecordsLog::CLINICAL_NOTES,
          action: 'filter',
          total_doc_refs: total,
          returned:,
          filtered: total - returned
        )
      end

      def log_notes_index_metrics(parsed_notes, start_date, end_date)
        total_notes = parsed_notes.size
        vista_count = parsed_notes.count { |n| n.source == SourceConstants::VISTA }
        oracle_health_count = parsed_notes.count { |n| n.source == SourceConstants::ORACLE_HEALTH }

        mr_log.diagnostic(
          resource: MedicalRecords::MedicalRecordsLog::CLINICAL_NOTES,
          action: 'index',
          total_notes:,
          vista_count:,
          oracle_health_count:,
          start_date:,
          end_date:
        )

        StatsD.gauge("#{self.class::STATSD_KEY_PREFIX}.clinical_notes.index.total", total_notes)
        StatsD.gauge("#{self.class::STATSD_KEY_PREFIX}.clinical_notes.index.vista", vista_count)
        StatsD.gauge("#{self.class::STATSD_KEY_PREFIX}.clinical_notes.index.oracle_health", oracle_health_count)
      end

      def log_notes_show_metrics(source, result)
        source_used = source || 'source not specified'
        found = result.present?

        mr_log.diagnostic(
          resource: MedicalRecords::MedicalRecordsLog::CLINICAL_NOTES,
          action: 'show',
          source: source_used,
          note_found: found,
          note_type: result&.note_type
        )

        StatsD.increment("#{self.class::STATSD_KEY_PREFIX}.clinical_notes.show.source", tags: ["source:#{source_used}"])
        StatsD.increment("#{self.class::STATSD_KEY_PREFIX}.clinical_notes.show.not_found") unless found
      end
    end
  end
end
