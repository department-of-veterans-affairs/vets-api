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
