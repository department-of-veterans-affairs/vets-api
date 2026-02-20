# frozen_string_literal: true

module UnifiedHealthData
  module Concerns
    # Logging and metrics methods for clinical notes operations.
    # Extracted from Service to keep class length manageable.
    module ClinicalNotesLogging
      extend ActiveSupport::Concern

      private

      def log_loinc_codes_enabled?
        Flipper.enabled?(:mhv_accelerated_delivery_uhd_loinc_logging_enabled, @user)
      end

      def clinical_notes_logging_enabled?
        Flipper.enabled?(:mhv_accelerated_delivery_uhd_clinical_notes_logging_enabled, @user)
      end

      def log_notes_response_count(total, returned)
        Rails.logger.info(
          "Clinical Notes response: total_doc_refs=#{total}, returned=#{returned}, filtered=#{total - returned}",
          { service: 'unified_health_data' }
        )
      end

      def log_notes_index_metrics(parsed_notes, start_date, end_date)
        total_notes = parsed_notes.size
        vista_count = parsed_notes.count { |n| n.source == SourceConstants::VISTA }
        oracle_health_count = parsed_notes.count { |n| n.source == SourceConstants::ORACLE_HEALTH }

        Rails.logger.info(
          {
            message: 'Clinical Notes index response',
            total_notes:,
            vista_count:,
            oracle_health_count:,
            start_date:,
            end_date:,
            service: 'unified_health_data'
          }
        )

        StatsD.gauge("#{self.class::STATSD_KEY_PREFIX}.clinical_notes.index.total", total_notes)
        StatsD.gauge("#{self.class::STATSD_KEY_PREFIX}.clinical_notes.index.vista", vista_count)
        StatsD.gauge("#{self.class::STATSD_KEY_PREFIX}.clinical_notes.index.oracle_health", oracle_health_count)
      end

      def log_notes_show_metrics(source, result)
        source_used = source || 'source not specified'
        found = result.present?

        Rails.logger.info(
          {
            message: 'Clinical Notes show request',
            source: source_used,
            note_found: found,
            note_type: result&.note_type,
            service: 'unified_health_data'
          }
        )

        StatsD.increment("#{self.class::STATSD_KEY_PREFIX}.clinical_notes.show.source", tags: ["source:#{source_used}"])
        StatsD.increment("#{self.class::STATSD_KEY_PREFIX}.clinical_notes.show.not_found") unless found
      end
    end
  end
end
