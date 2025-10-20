# frozen_string_literal: true

require_relative '../models/lab_or_test'
require_relative '../reference_range_formatter'

module UnifiedHealthData
  module Adapters
    class LabOrTestAdapter
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

        contained = record['resource']['contained']
        code = get_code(record)
        encoded_data = record['resource']['presentedForm'] ? record['resource']['presentedForm'].first['data'] : ''
        observations = get_observations(record)
        return nil unless code && (encoded_data || observations)

        log_warnings(record, encoded_data, observations)

        UnifiedHealthData::LabOrTest.new(
          id: record['resource']['id'],
          type: record['resource']['resourceType'],
          display: format_display(record),
          test_code: code,
          date_completed: record['resource']['effectiveDateTime'],
          sample_tested: get_sample_tested(record['resource'], contained),
          encoded_data:,
          location: get_location(record),
          ordered_by: get_ordered_by(record),
          observations:,
          body_site: get_body_site(record['resource'], contained)
        )
      end

      private

      def log_warnings(record, encoded_data, observations)
        log_final_status_warning(record, record['resource']['status'], encoded_data, observations)
        log_missing_date_warning(record)
      end

      def log_final_status_warning(record, status, encoded_data, observations)
        return unless status == 'final' && encoded_data.blank? && observations.blank?

        Rails.logger.warn(
          "DiagnosticReport #{record['resource']['id']} has status 'final' but is missing " \
          'both encoded data and observations',
          { service: 'mhv-medical-records' }
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
            { service: 'mhv-medical-records' }
          )
        elsif effective_period.present? && effective_period['start'].blank?
          Rails.logger.warn(
            "DiagnosticReport #{resource['id']} is missing effectivePeriod.start",
            { service: 'mhv-medical-records' }
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

        record['resource']['contained'].select { |resource| resource['resourceType'] == 'Observation' }.map do |obs|
          sample_tested = get_sample_tested(obs, record['resource']['contained'])
          body_site = get_body_site(obs, record['resource']['contained'])
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
    end
  end
end
