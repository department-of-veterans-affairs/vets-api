# frozen_string_literal: true
require 'common/client/base'
require_relative 'configuration'
require_relative 'medical_record'

module UnifiedHealthData
  class Service < Common::Client::Base
    configuration UnifiedHealthData::Configuration

    def get_medical_records
      token = fetch_access_token
      response = perform(:get, 'path/to/medical_records', nil, { 'Authorization' => "Bearer #{token}" })
      response.body.map do |record|
        attributes = UnifiedHealthData::MedicalRecord::Attributes.new(
          display: record['attributes']['display'],
          test_code: record['attributes']['testCode'],
          date_completed: record['attributes']['dateCompleted'],
          sample_site: record['attributes']['sampleSite'],
          encoded_data: record['attributes']['encodedData'],
          location: record['attributes']['location']
        )
        UnifiedHealthData::MedicalRecord.new(
          id: record['id'],
          type: record['type'],
          attributes: attributes
        )
      end
    end

    private

    def fetch_access_token
      response = connection.post(configuration.token_path) do |req|
        req.headers['Content-Type'] = 'application/json'
        req.body = {
          appId: configuration.app_id,
          appToken: configuration.app_token,
          subject: 'VA.gov SCDF Proxy Client',
          userType: 'SYSTEM'
        }.to_json
      end
      response.body['access_token']
    end
  end
end
