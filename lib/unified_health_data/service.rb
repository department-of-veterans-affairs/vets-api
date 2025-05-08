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
        token = fetch_access_token
        patient_id = @user.icn
        path = "#{config.base_path}labs?patientId=#{patient_id}&startDate=#{start_date}&endDate=#{end_date}"
        response = perform(:get, path, nil, { 'Authorization' => token })
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
      vista_records = body.dig('vista', 'entry') || []
      oracle_health_records = body.dig('oracle-health', 'entry') || []
      vista_records + oracle_health_records
    end

    def parse_labs(records)
      records = records.select { |record| record['resource']['resourceType'] == 'DiagnosticReport' }.map do |record|
        parse_single_record(record)
      end
      records.compact
    end

    def parse_single_record(record)
      location = fetch_location(record)
      code = fetch_code(record)
      encoded_data = record['resource']['presentedForm'] ? record['resource']['presentedForm'].first['data'] : ''
      sample_tested = fetch_sample_tested(record['resource'], record['resource']['contained'])
      body_site = fetch_body_site(record['resource'], record['resource']['contained'])
      observations = fetch_observations(record)
      ordered_by = fetch_ordered_by(record)

      return nil unless code && (encoded_data || observations)

      attributes = UnifiedHealthData::Attributes.new(
        display: record['resource']['code']['text'],
        test_code: code,
        date_completed: record['resource']['effectiveDateTime'],
        sample_tested:, encoded_data:, location:, ordered_by:, observations:, body_site:
      )

      UnifiedHealthData::LabOrTest.new(
        id: record['resource']['id'],
        type: record['resource']['resourceType'],
        attributes:
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
      return if record['resource']['category'].empty?

      coding = record['resource']['category'].find do |category|
        category['coding'].count && category['coding'][0]['code'] != 'LAB'
      end
      coding ? coding['coding'][0]['code'] : nil
    end

    def fetch_body_site(resource, contained)
      body_sites = []

      return '' unless resource['basedOn']

      service_request_references = resource['basedOn'].pluck('reference')
      service_request_references.each do |reference|
        service_request_object = contained.find do |contained_resource|
          contained_resource['resourceType'] == 'ServiceRequest' &&
            contained_resource['id'] == extract_reference_id(reference)
        end
        body_site_object = service_request_object['bodySite'] if service_request_object
        body_site_object&.each do |body_site|
          body_sites << body_site['text']
        end
      end

      body_sites.join(', ').strip
    end

    def fetch_sample_tested(record, contained)
      return '' unless record['specimen']

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
      record['resource']['contained'].select { |resource| resource['resourceType'] == 'Observation' }.map do |obs|
        sample_tested = fetch_sample_tested(obs, record['resource']['contained'])
        body_site = fetch_body_site(obs, record['resource']['contained'])
        UnifiedHealthData::Observation.new(
          test_code: obs['code']['text'],
          value: fetch_observation_value(obs),
          reference_range: if obs['referenceRange']
                             obs['referenceRange'].map do |range|
                               range['text']
                             end.join(', ').strip
                           else
                             ''
                           end,
          status: obs['status'],
          comments: obs['note']&.map { |note| note['text'] }&.join(', ') || '',
          sample_tested:,
          body_site:
        )
      end
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
