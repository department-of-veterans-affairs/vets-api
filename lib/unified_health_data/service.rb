# frozen_string_literal: true
require 'common/client/base'
require_relative 'configuration'
require_relative 'medical_record'

module UnifiedHealthData
  class Service < Common::Client::Base
    configuration UnifiedHealthData::Configuration

    def initialize(user)
      @user = user
    end

    def get_medical_records
      token = fetch_access_token
      patient_id = @user.icn
      start_date = '2024-01-01'
      end_date = '2024-12-31'
      path = "#{config.base_path}labs?patient-id=#{patient_id}&start-date=#{start_date}&end-date=#{end_date}"
      response = perform(:get, path, nil, { 'Authorization' => token })

      vista_records = response.body.dig('vista', 'entry') || []
      oracle_health_records = response.body.dig('oracle-health', 'entry') || []
      combined_records = vista_records + oracle_health_records

      combined_records.map do |record|
        # Get the name of the first organization resource if contained exists, otherwise set to nil
        if record['resource']['contained'].nil?
          location = nil
        else
          location_object = record['resource']['contained'].find { |resource| resource['resourceType'] == 'Organization' }
          location = location_object.nil? ? nil : location_object['name']
        end

        # Get the first code from the category array that is not 'LAB'
        code_array = record['resource']['category'].find { |category| category['coding'][0]['code'] != 'LAB' }
        code = code_array['coding'][0]

        # Get the sample site from the contained Specimen resource
        specimen = record['resource']['contained'].find { |resource| resource['resourceType'] == 'Specimen' }
        sample_site = specimen ? specimen['type']&.dig('text') : ''

        observations = record['resource']['contained'].select { |resource| resource['resourceType'] == 'Observation' }.map do |obs|
          UnifiedHealthData::MedicalRecord::Attributes::Observation.new(
            test_code: obs['code']['text'],
            encoded_data: '',
            value_quantity: obs['valueQuantity'] ? "#{obs['valueQuantity']['value']} #{obs['valueQuantity']['unit']}".strip : '',
            reference_range: obs['referenceRange'] ? obs['referenceRange'].map { |range| range['text'] }.join(', ').strip : '',
            status: obs['status'],
            comments: obs['note']&.map { |note| note['text'] }&.join(', ') || ''
          )
        end

        ordered_by = if record['resource']['contained']
                       practitioner_object = record['resource']['contained'].find { |resource| resource['resourceType'] == 'Practitioner' }
                       if practitioner_object
                         name = practitioner_object['name'].first
                         "#{name['given'].join(' ')} #{name['family']}"
                       end
                     end

        attributes = UnifiedHealthData::MedicalRecord::Attributes.new(
          display: code['display'],
          test_code: record['resource']['code']['text'],
          date_completed: record['resource']['effectiveDateTime'],
          sample_site: sample_site,
          encoded_data: '',
          location:,
          ordered_by:,
          observations:,
        )

        UnifiedHealthData::MedicalRecord.new(
          id: record['resource']['id'],
          type: record['resource']['resourceType'],
          attributes:
        )
      end
    end

    private

    def fetch_access_token
      response = connection.post(config.token_path) do |req|
        req.headers['Content-Type'] = 'application/json'
        req.body = {
          appId: config.app_id,
          appToken: config.app_token,
          subject: 'VA.gov SCDF Proxy Client',
          userType: 'SYSTEM'
        }.to_json
      end
      response.headers['authorization']
    end
  end
end
