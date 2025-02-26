# frozen_string_literal: true

require 'common/client/base'
require_relative 'configuration'
require_relative 'models/medical_record'

module UnifiedHealthData
  class Service < Common::Client::Base
    configuration UnifiedHealthData::Configuration

    def initialize(user)
      super()
      @user = user
    end

    def get_medical_records(start_date:, end_date:)
      token = fetch_access_token
      patient_id = @user.icn
      path = "#{config.base_path}labs?patient-id=#{patient_id}&start-date=#{start_date}&end-date=#{end_date}"
      response = perform(:get, path, nil, { 'Authorization' => token })
      body = parse_response_body(response.body)

      combined_records = fetch_combined_records(body)
      parse_medical_records(combined_records)
    end

    private

    def fetch_access_token
      response = connection.post(config.token_path) do |req|
        req.headers['Content-Type'] = 'application/json'
        req.body = {
          appId: config.app_id,
          appToken: config.app_token,
          subject: config.subject,
          userType: config.user_type,
        }.to_json
      end
      response.headers['authorization']
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

    def parse_medical_records(records)
      records.select { |record| record['resource']['resourceType'] == 'DiagnosticReport' }.map do |record|
        parse_single_record(record)
      end
    end

    def parse_single_record(record)
      location = fetch_location(record)
      code = fetch_code(record)
      sample_site = fetch_sample_site(record)
      observations = fetch_observations(record)
      ordered_by = fetch_ordered_by(record)

      attributes = UnifiedHealthData::MedicalRecord::Attributes.new(
        display: code['display'],
        test_code: record['resource']['code']['text'],
        date_completed: record['resource']['effectiveDateTime'],
        sample_site:,
        encoded_data: record['resource']['presentedForm'] ? record['resource']['presentedForm'].first['data'] : '',
        location:,
        ordered_by:,
        observations:
      )

      UnifiedHealthData::MedicalRecord.new(
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
      code_array = record['resource']['category'].find { |category| category['coding'][0]['code'] != 'LAB' }
      code_array['coding'][0]
    end

    def fetch_sample_site(record)
      specimen = record['resource']['contained'].find { |resource| resource['resourceType'] == 'Specimen' }
      specimen ? specimen['type']&.dig('text') : ''
    end

    def fetch_observations(record)
      record['resource']['contained'].select { |resource| resource['resourceType'] == 'Observation' }.map do |obs|
        UnifiedHealthData::MedicalRecord::Attributes::Observation.new(
          test_code: obs['code']['text'],
          value_quantity: if obs['valueQuantity']
                            "#{obs['valueQuantity']['value']} #{obs['valueQuantity']['unit']}".strip
                          else
                            ''
                          end,
          reference_range: if obs['referenceRange']
                             obs['referenceRange'].map do |range|
                               range['text']
                             end.join(', ').strip
                           else
                             ''
                           end,
          status: obs['status'],
          comments: obs['note']&.map { |note| note['text'] }&.join(', ') || ''
        )
      end
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
  end
end
