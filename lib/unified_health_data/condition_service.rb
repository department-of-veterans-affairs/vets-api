# frozen_string_literal: true

require 'common/client/base'
require 'unified_health_data/models/condition'

module UnifiedHealthData
  class ConditionService < Common::Client::Base
    include Common::Client::Concerns::Monitoring

    configuration UnifiedHealthData::Configuration

    STATSD_KEY_PREFIX = 'api.unified_health_data.conditions'

    def initialize(user)
      @user = user
      super()
    end

    def get_conditions
      with_monitoring do
        headers = { 'Authorization' => fetch_access_token, 'x-api-key' => config.x_api_key }
        patient_id = @user.icn
        path = "#{config.base_path}conditions?patientId=#{patient_id}"
        response = perform(:get, path, nil, headers)
        body = parse_response_body(response.body)

        combined_records = fetch_combined_records(body)
        parsed_records = parse_conditions(combined_records)

        Rails.logger.info(
          message: 'UHD conditions fetch completed',
          total_records: parsed_records.size,
          service: 'unified_health_data_conditions'
        )

        parsed_records
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
            patientId: @user.icn
          }.to_json
        end
        JSON.parse(response.body)['accessToken']
      end
    end

    def parse_response_body(response_body)
      JSON.parse(response_body)
    rescue JSON::ParserError => e
      Rails.logger.error "Error parsing response body: #{e.message}"
      raise Common::Exceptions::BackendServiceException.new(
        'FHIR_PARSE_ERROR',
        detail: 'Failed to parse FHIR response'
      )
    end

    def fetch_combined_records(body)
      vista_records = body.dig('vista', 'entry') || []
      oracle_health_records = body.dig('oracle-health', 'entry') || []

      vista_records + oracle_health_records
    end

    def parse_conditions(records)
      return [] if records.blank?

      condition_records = records.select do |record|
        record['resource'] && record['resource']['resourceType'] == 'Condition'
      end

      parsed_conditions = condition_records.map { |record| parse_single_condition(record) }
      parsed_conditions.compact
    end

    def parse_single_condition(record)
      return nil if record.nil? || record['resource'].nil?

      attributes = build_condition_attributes(record)

      UnifiedHealthData::Condition.new(
        id: record['resource']['id'],
        type: record['resource']['resourceType'],
        attributes:
      )
    end

    def build_condition_attributes(record)
      resource = record['resource']

      UnifiedHealthData::ConditionAttributes.new(
        date: extract_condition_date(resource),
        name: extract_condition_name(resource),
        provider: extract_condition_provider(resource),
        facility: extract_condition_facility(resource),
        comments: extract_condition_comments(resource)
      )
    end

    def extract_condition_name(resource)
      if resource.dig('code', 'text').present?
        resource['code']['text']
      elsif resource.dig('code', 'coding')&.any?
        codings = resource['code']['coding']
        displays = codings.map { |c| c['display'] || c['code'] }.compact
        displays.any? ? displays.join(', ') : nil
      end
    end

    def extract_condition_provider(resource)
      if resource['recorder']&.dig('reference')
        ref = resource['recorder']['reference']
        contained_resource = extract_contained_resource(resource, ref)
        if contained_resource&.dig('name')&.any?
          name_obj = contained_resource['name'].first
          return format_name_first_to_last(name_obj)
        end
      end
      return resource['asserter']['display'] if resource.dig('asserter', 'display').present?

      if resource['contained']&.any?
        practitioner = resource['contained'].find { |item| item['resourceType'] == 'Practitioner' }
        if practitioner&.dig('name')&.any?
          name_obj = practitioner['name'].first
          return name_obj['text'] || build_name_from_parts(name_obj)
        end
      end

      nil
    end

    def extract_condition_facility(resource)
      if resource.dig('recorder', 'extension')&.any?
        extension = resource['recorder']['extension'].first
        ref = extension&.dig('valueReference', 'reference')
        if ref
          contained_resource = extract_contained_resource(resource, ref)
          return contained_resource['name'] if contained_resource&.dig('name')
        end
      end

      if resource.dig('encounter', 'reference')&.include?('Location/')
        location_id = resource['encounter']['reference'].split('/').last
        location = resource['contained']&.find do |item|
          item['resourceType'] == 'Location' && item['id'] == location_id
        end
        return location['name'] if location
      end

      if resource['contained']&.any?
        location = resource['contained'].find { |item| item['resourceType'] == 'Location' }
        return location['name'] if location
      end

      nil
    end

    def extract_condition_date(resource)
      date = resource['recordedDate'] ||
             resource['onsetDateTime'] ||
             resource.dig('onsetPeriod', 'start') ||
             resource['abatementDateTime']

      return nil unless date

      begin
        DateTime.parse(date).iso8601
      rescue ArgumentError
        date.to_s
      end
    end

    def extract_condition_comments(resource)
      if resource['note']&.any?
        notes = resource['note'].map { |note| note['text'] }.compact
        return notes.join('; ') if notes.any?
      end

      status_text = resource.dig('clinicalStatus', 'text') ||
                    resource.dig('verificationStatus', 'text')

      status_text.presence
    end

    def build_name_from_parts(name_obj)
      return '' unless name_obj.is_a?(Hash)

      parts = []
      parts << name_obj['given']&.join(' ') if name_obj['given']&.any?
      parts << name_obj['family'] if name_obj['family']
      parts.join(' ').strip
    end

    def extract_contained_resource(resource, reference)
      return nil unless reference && resource['contained']&.any?

      resource_id = reference.split('/').last

      resource['contained'].find { |item| item['id'] == resource_id }
    end

    def format_name_first_to_last(name_obj)
      return nil unless name_obj.is_a?(Hash)

      return name_obj['text'] if name_obj['text']

      parts = []
      parts << name_obj['given']&.join(' ') if name_obj['given']&.any?
      parts << name_obj['family'] if name_obj['family']
      parts.join(' ').strip.presence
    end
  end
end
