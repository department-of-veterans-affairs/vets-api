# frozen_string_literal: true

require 'common/client/base'
require 'common/exceptions/not_implemented'
require_relative 'configuration'
require_relative 'models/lab_or_test'

module UnifiedHealthData
  class Service < Common::Client::Base
    STATSD_KEY_PREFIX = 'api.uhd'
    include Common::Client::Concerns::Monitoring

    configuration UnifiedHealthData::Configuration

    def initialize(user)
      super()
      @user = user
    end

    def get_labs(start_date:, end_date:)
      with_monitoring do
        headers = { 'Authorization' => fetch_access_token, 'x-api-key' => config.x_api_key }
        patient_id = @user.icn
        path = "#{config.base_path}labs?patientId=#{patient_id}&startDate=#{start_date}&endDate=#{end_date}"
        response = perform(:get, path, nil, headers)
        body = parse_response_body(response.body)

        combined_records = fetch_combined_records(body)
        parsed_records = parse_labs(combined_records)
        filter_records(parsed_records)
      end
    end

    private

    def fetch_access_token
      with_monitoring do
        response = connection.post(config.token_path) do |req|
          req.headers['Content-Type'] = 'application/json'
          req.body = {
            appId: config.app_id,
            appToken: config.app_token,
            subject: config.subject,
            userType: config.user_type
          }.to_json
        end
        response.headers['authorization']
      end
    end

    def filter_records(records)
      records.select do |record|
        case record.attributes.test_code
        when 'CH'
          Flipper.enabled?(:mhv_accelerated_delivery_uhd_ch_enabled, @user)
        when 'SP'
          Flipper.enabled?(:mhv_accelerated_delivery_uhd_sp_enabled, @user)
        end
      end
    end

    def parse_response_body(body)
      # FIXME: workaround for testing
      body.is_a?(String) ? JSON.parse(body) : body
    end

    def fetch_combined_records(body)
      return [] if body.nil?

      vista_records = body.dig('vista', 'entry') || []
      oracle_health_records = body.dig('oracle-health', 'entry') || []
      vista_records + oracle_health_records
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
        display: record['resource']['code'] ? record['resource']['code']['text'] : '',
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
          reference_range: parse_reference_range(obs['referenceRange']),
          status: obs['status'],
          comments: obs['note']&.map { |note| note['text'] }&.join(', ') || '',
          sample_tested:,
          body_site:
        )
      end
    end

    def parse_reference_range(reference_range)
      return '' unless reference_range

      reference_range.map do |range|
        if range['text']
          range['text']
        elsif range['low'] && range['high'] && range['type']
          type_text = range['type']['text'] || range.dig('type', 'coding', 0, 'display') || ''
          low_value = "#{range['low']['value']} #{range['low']['unit']}"
          high_value = "#{range['high']['value']} #{range['high']['unit']}"
          "#{type_text}: #{low_value} - #{high_value}".strip
        elsif range['low'] && range['high']
          "#{range['low']['value']} #{range['low']['unit']} - #{range['high']['value']} #{range['high']['unit']}"
        else
          ''
        end
      end.reject(&:empty?).join(', ').strip
    end

    def fetch_observation_value(obs)
      type, text = if obs['valueQuantity']
                     ['quantity', "#{obs['valueQuantity']['value']} #{obs['valueQuantity']['unit']}"]
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
  end
end
