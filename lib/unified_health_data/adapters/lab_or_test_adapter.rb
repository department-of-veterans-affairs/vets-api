# frozen_string_literal: true

require_relative '../models/lab_or_test'
require_relative '../reference_range_formatter'
require_relative 'date_normalizer'

module UnifiedHealthData
  module Adapters
    class LabOrTestAdapter
      include DateNormalizer

      ALLOWED_STATUSES = %w[final amended corrected appended].freeze

      # HL7 v2-0074 diagnostic service section codes to user-friendly display names
      TEST_CODE_DISPLAY_MAP = {
        'CH' => 'Chemistry and hematology',
        'MI' => 'Microbiology',
        'SP' => 'Surgical Pathology',
        'CY' => 'Cytology',
        'EM' => 'Electron Microscopy'
      }.freeze

      def parse_labs(records)
        return [] if records.blank?

        filtered = records.select do |record|
          record['resource'] && record['resource']['resourceType'] == 'DiagnosticReport'
        end
        parsed = filtered.map { |record| parse_single_record(record) }
        parsed.compact
      end

      def parse_single_record(record)
        return nil if record.nil? || record['resource'].nil?

        # Filter out DiagnosticReports with disallowed status
        unless allowed_status?(record['resource']['status'])
          log_filtered_diagnostic_report(record, 'disallowed_status')
          return nil
        end

        contained = record['resource']['contained']
        code = get_code(record)
        encoded_data = get_encoded_data(record['resource'])
        observations = get_observations(record)

        # Log warnings before filtering out records
        log_warnings(record, encoded_data, observations)

        # Return nil if there's no code, and if there's no encoded data AND no valid observations
        unless code && (encoded_data.present? || observations.any?)
          log_filtered_diagnostic_report(record, 'no_valid_data')
          return nil
        end

        build_lab_or_test(record, code, encoded_data, observations, contained)
      end

      private

      def allowed_status?(status)
        ALLOWED_STATUSES.include?(status)
      end

      def build_lab_or_test(record, code, encoded_data, observations, contained)
        date_completed_value = get_date_completed(record['resource'])

        UnifiedHealthData::LabOrTest.new(
          id: record['resource']['id'],
          type: record['resource']['resourceType'],
          display: format_display(record),
          test_code: code,
          test_code_display: TEST_CODE_DISPLAY_MAP.fetch(code, code),
          date_completed: date_completed_value,
          sort_date: normalize_date_for_sorting(date_completed_value),
          sample_tested: get_sample_tested(record['resource'], contained),
          encoded_data:,
          location: get_location(record),
          ordered_by: get_ordered_by(record),
          observations:,
          body_site: get_body_site(record['resource'], contained),
          status: record['resource']['status'],
          source: record['source']
        )
      end

      def log_warnings(record, encoded_data, observations)
        log_final_status_warning(record, record['resource']['status'], encoded_data, observations)
        log_missing_date_warning(record)
      end

      def log_filtered_diagnostic_report(record, reason)
        resource = record['resource']
        status = resource['status']

        Rails.logger.info(
          "Filtered DiagnosticReport: id=#{resource['id']}, status=#{status}, reason=#{reason}",
          { service: 'unified_health_data', filtering: true }
        )

        StatsD.increment('unified_health_data.lab_or_test.filtered_diagnostic_report',
                         tags: ["reason:#{reason}"])
      end

      def log_filtered_observations(record, filtered_count, total_count)
        resource = record['resource']

        Rails.logger.info(
          "Filtered #{filtered_count}/#{total_count} Observations from DiagnosticReport #{resource['id']}",
          { service: 'unified_health_data', filtering: true }
        )

        # Increment the counter once per DiagnosticReport that has filtered observations
        StatsD.increment('unified_health_data.lab_or_test.filtered_observations')
      end

      def log_final_status_warning(record, status, encoded_data, observations)
        return unless status == 'final' && encoded_data.blank? && observations.blank?

        patient_reference = record['resource']&.dig('subject', 'reference')
        # Last four of FHIR Patient.id
        patient_last_four = patient_reference&.split('/')&.last&.last(4) || 'unknown'

        Rails.logger.warn(
          "DiagnosticReport #{record['resource']['id']} has status 'final' but is missing " \
          "both encoded data and observations (Patient: #{patient_last_four})",
          { service: 'unified_health_data' }
        )
      end

      def log_missing_date_warning(record)
        resource = record['resource']
        effective_date_time = resource['effectiveDateTime']
        effective_period = resource['effectivePeriod']

        # effectiveDateTime and effectivePeriod are mutually exclusive per FHIR R4
        # Log when both are missing OR when effectivePeriod exists but has no start
        if effective_date_time.blank? && effective_period.blank?
          Rails.logger.warn(
            "DiagnosticReport #{resource['id']} is missing effectiveDateTime and effectivePeriod",
            { service: 'unified_health_data' }
          )
        elsif effective_period.present? && effective_period['start'].blank?
          Rails.logger.warn(
            "DiagnosticReport #{resource['id']} is missing effectivePeriod.start",
            { service: 'unified_health_data' }
          )
        end
      end

      def get_location(record)
        if record['resource']['contained'].nil?
          nil
        else
          location_object = record['resource']['contained'].find do |resource|
            resource['resourceType'] == 'Organization'
          end
          location_object.nil? ? nil : location_object['name']
        end
      end

      def get_code(record)
        return nil if record['resource']['category'].blank?

        coding = record['resource']['category'].find do |category|
          category['coding'].present? && category['coding'][0]['code'] != 'LAB'
        end
        coding ? coding['coding'][0]['code'] : nil
      end

      def get_body_site(resource, contained)
        body_sites = []

        return '' unless resource['basedOn']
        return '' if contained.nil?

        service_request_references = resource['basedOn'].pluck('reference')
        service_request_references.each do |reference|
          service_request_object = contained.find do |contained_resource|
            contained_resource['resourceType'] == 'ServiceRequest' &&
              contained_resource['id'] == get_reference_id(reference)
          end

          next unless service_request_object && service_request_object['bodySite']

          service_request_object['bodySite'].each do |body_site|
            next unless body_site['coding'].is_a?(Array)

            body_site['coding'].each do |coding|
              body_sites << coding['display'] if coding['display']
            end
          end
        end

        body_sites.join(', ').strip
      end

      def get_sample_tested(record, contained)
        return '' unless record['specimen']
        return '' if contained.nil?

        specimen_references = if record['specimen'].is_a?(Hash)
                                [get_reference_id(record['specimen']['reference'])]
                              elsif record['specimen'].is_a?(Array)
                                record['specimen'].map { |specimen| get_reference_id(specimen['reference']) }
                              end

        specimens =
          specimen_references.map do |reference|
            specimen_object = contained.find do |resource|
              resource['resourceType'] == 'Specimen' && resource['id'] == reference
            end
            specimen_object&.dig('type', 'text')
          end

        specimens.compact.join(', ').strip
      end

      def get_observations(record)
        return [] if record['resource']['contained'].nil?

        all_observations = record['resource']['contained'].select do |resource|
          resource['resourceType'] == 'Observation'
        end
        filtered_count = 0

        valid_observations = all_observations.filter_map do |obs|
          # Filter out observations with disallowed status
          unless allowed_status?(obs['status'])
            filtered_count += 1
            next
          end

          build_observation(obs, record['resource']['contained'])
        end

        # Log and track filtered observations
        log_filtered_observations(record, filtered_count, all_observations.size) if filtered_count.positive?

        valid_observations
      end

      def build_observation(obs, contained)
        sample_tested = get_sample_tested(obs, contained)
        body_site = get_body_site(obs, contained)
        UnifiedHealthData::Observation.new(
          test_code: obs['code']['text'],
          value: format_observation_value(obs),
          reference_range: UnifiedHealthData::ReferenceRangeFormatter.format(obs),
          status: obs['status'],
          comments: obs['note']&.map { |note| note['text'] }&.join(', ') || '',
          sample_tested:,
          body_site:
        )
      end

      def format_observation_value(obs)
        type, text = if obs['valueQuantity']
                       ['quantity', format_quantity_value(obs['valueQuantity'])]
                     elsif obs['valueCodeableConcept']
                       ['codeable-concept', obs['valueCodeableConcept']['text']]
                     elsif obs['valueString']
                       ['string', obs['valueString']]
                     elsif obs['valueDateTime']
                       ['date-time', obs['valueDateTime']]
                     elsif obs['valueAttachment']
                       Rails.logger.error(
                         message: "Observation with ID #{obs['id']} has unsupported value type: Attachment"
                       )
                       raise Common::Exceptions::NotImplemented
                     else
                       [nil, nil]
                     end
        { text:, type: }
      end

      def format_quantity_value(value_quantity)
        value = value_quantity['value']
        unit = value_quantity['unit']
        comparator = value_quantity['comparator']

        result_text = ''
        result_text += comparator.to_s if comparator.present?
        result_text += value.to_s
        result_text += " #{unit}" if unit.present?

        result_text
      end

      def get_ordered_by(record)
        if record['resource']['contained']
          practitioner_object = record['resource']['contained'].find do |resource|
            resource['resourceType'] == 'Practitioner'
          end
          if practitioner_object
            name = practitioner_object['name'].first
            "#{name['given'].join(' ')} #{name['family']}"
          end
        end
      end

      def get_reference_id(reference)
        reference.split('/').last
      end

      def format_display(record)
        contained = record['resource']['contained']
        if contained&.any? { |r| r['resourceType'] == 'ServiceRequest' && r['code']&.dig('text').present? }
          service_request = contained.find do |r|
            r['resourceType'] == 'ServiceRequest' && r['code']&.dig('text').present?
          end
          service_request['code']['text']
        else
          record['resource']['code'] ? record['resource']['code']['text'] : ''
        end
      end

      def get_encoded_data(resource)
        return '' unless resource['presentedForm']&.any?

        # Find the presentedForm item with contentType 'text/plain'
        presented_form = resource['presentedForm'].find { |form| form['contentType'] == 'text/plain' }
        return '' unless presented_form

        # Handle standard data field or extensions indicating data-absent-reason
        # Return empty string when data is absent (either with data-absent-reason extension or missing)
        presented_form['data'] || ''
      end

      def get_date_completed(resource)
        # Handle both effectiveDateTime and effectivePeriod formats
        if resource['effectiveDateTime']
          resource['effectiveDateTime']
        elsif resource['effectivePeriod']&.dig('start')
          resource['effectivePeriod']['start']
        end
      end
    end
  end
end
