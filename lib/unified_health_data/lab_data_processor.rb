# frozen_string_literal: true

require_relative 'models/lab_or_test'
require_relative 'reference_range_formatter'

module UnifiedHealthData
  class LabDataProcessor
    def initialize(user)
      @user = user
    end

    def process_labs(records)
      return all_records_response(records) unless filtering_enabled?

      apply_test_code_filtering(records)
    end

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

      code = fetch_code(record)
      encoded_data = record['resource']['presentedForm'] ? record['resource']['presentedForm'].first['data'] : ''
      observations = fetch_observations(record)
      return nil unless code && (encoded_data || observations)

      attributes = build_lab_or_test_attributes(record)

      UnifiedHealthData::LabOrTest.new(
        id: record['resource']['id'],
        type: record['resource']['resourceType'],
        attributes:
      )
    end

    private

    def filtering_enabled?
      Flipper.enabled?(:mhv_accelerated_delivery_uhd_filtering_enabled, @user)
    end

    def all_records_response(records)
      Rails.logger.info(
        message: 'UHD filtering disabled - returning all records',
        total_records: records.size,
        service: 'unified_health_data'
      )
      records
    end

    def apply_test_code_filtering(records)
      filtered = records.select { |record| test_code_enabled?(record.attributes.test_code) }

      Rails.logger.info(
        message: 'UHD filtering enabled - applied test code filtering',
        total_records: records.size,
        filtered_records: filtered.size,
        service: 'unified_health_data'
      )

      filtered
    end

    def test_code_enabled?(test_code)
      case test_code
      when 'CH'
        Flipper.enabled?(:mhv_accelerated_delivery_uhd_ch_enabled, @user)
      when 'SP'
        Flipper.enabled?(:mhv_accelerated_delivery_uhd_sp_enabled, @user)
      when 'MB'
        Flipper.enabled?(:mhv_accelerated_delivery_uhd_mb_enabled, @user)
      else
        false # Reject any other test codes for now, but we'll log them for analysis
      end
    end

    def build_lab_or_test_attributes(record)
      location = fetch_location(record)
      code = fetch_code(record)
      encoded_data = record['resource']['presentedForm'] ? record['resource']['presentedForm'].first['data'] : ''
      contained = record['resource']['contained']
      sample_tested = fetch_sample_tested(record['resource'], contained)
      body_site = fetch_body_site(record['resource'], contained)
      observations = fetch_observations(record)
      ordered_by = fetch_ordered_by(record)

      UnifiedHealthData::Attributes.new(
        display: fetch_display(record),
        test_code: code,
        date_completed: record['resource']['effectiveDateTime'],
        sample_tested:,
        encoded_data:,
        location:,
        ordered_by:,
        observations:,
        body_site:
      )
    end

    def fetch_location(record)
      if record['resource']['contained'].nil?
        nil
      else
        location_object = record['resource']['contained'].find { |resource| resource['resourceType'] == 'Organization' }
        location_object.nil? ? nil : location_object['name']
      end
    end

    def fetch_code(record)
      return nil if record['resource']['category'].blank?

      coding = record['resource']['category'].find do |category|
        category['coding'].present? && category['coding'][0]['code'] != 'LAB'
      end
      coding ? coding['coding'][0]['code'] : nil
    end

    def fetch_body_site(resource, contained)
      body_sites = []

      return '' unless resource['basedOn']
      return '' if contained.nil?

      service_request_references = resource['basedOn'].pluck('reference')
      service_request_references.each do |reference|
        service_request_object = contained.find do |contained_resource|
          contained_resource['resourceType'] == 'ServiceRequest' &&
            contained_resource['id'] == extract_reference_id(reference)
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

    def fetch_sample_tested(record, contained)
      return '' unless record['specimen']
      return '' if contained.nil?

      specimen_references = if record['specimen'].is_a?(Hash)
                              [extract_reference_id(record['specimen']['reference'])]
                            elsif record['specimen'].is_a?(Array)
                              record['specimen'].map { |specimen| extract_reference_id(specimen['reference']) }
                            end

      specimens =
        specimen_references.map do |reference|
          specimen_object = contained.find do |resource|
            resource['resourceType'] == 'Specimen' && resource['id'] == reference
          end
          specimen_object['type']['text'] if specimen_object
        end

      specimens.compact.join(', ').strip
    end

    def fetch_observations(record)
      return [] if record['resource']['contained'].nil?

      record['resource']['contained'].select { |resource| resource['resourceType'] == 'Observation' }.map do |obs|
        sample_tested = fetch_sample_tested(obs, record['resource']['contained'])
        body_site = fetch_body_site(obs, record['resource']['contained'])
        UnifiedHealthData::Observation.new(
          test_code: obs['code']['text'],
          value: fetch_observation_value(obs),
          reference_range: UnifiedHealthData::ReferenceRangeFormatter.format(obs),
          status: obs['status'],
          comments: obs['note']&.map { |note| note['text'] }&.join(', ') || '',
          sample_tested:,
          body_site:
        )
      end
    end

    def fetch_observation_value(obs)
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

    def fetch_ordered_by(record)
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

    def extract_reference_id(reference)
      reference.split('/').last
    end

    def fetch_display(record)
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
