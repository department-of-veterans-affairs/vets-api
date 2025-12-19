# frozen_string_literal: true

require 'common/client/base'
require_relative 'configuration'

module UnifiedHealthData
  class Client < Common::Client::Base
    STATSD_KEY_PREFIX = 'api.uhd'
    include Common::Client::Concerns::Monitoring

    configuration UnifiedHealthData::Configuration

    def get_allergies_by_date(patient_id:, start_date:, end_date:)
      path = "#{config.base_path}allergies?patientId=#{patient_id}&startDate=#{start_date}&endDate=#{end_date}"
      perform(:get, path, nil, request_headers)
    end

    def get_labs_by_date(patient_id:, start_date:, end_date:)
      path = "#{config.base_path}labs?patientId=#{patient_id}&startDate=#{start_date}&endDate=#{end_date}"
      perform(:get, path, nil, request_headers)
    end

    def get_conditions_by_date(patient_id:, start_date:, end_date:)
      path = "#{config.base_path}conditions?patientId=#{patient_id}&startDate=#{start_date}&endDate=#{end_date}"
      perform(:get, path, nil, request_headers)
    end

    def get_notes_by_date(patient_id:, start_date:, end_date:)
      path = "#{config.base_path}notes?patientId=#{patient_id}&startDate=#{start_date}&endDate=#{end_date}"
      perform(:get, path, nil, request_headers)
    end

    def get_vitals_by_date(patient_id:, start_date:, end_date:)
      path = "#{config.base_path}vitals?patientId=#{patient_id}&startDate=#{start_date}&endDate=#{end_date}"
      perform(:get, path, nil, request_headers)
    end

    def get_immunizations_by_date(patient_id:, start_date:, end_date:)
      path = "#{config.base_path}immunizations?patientId=#{patient_id}&startDate=#{start_date}&endDate=#{end_date}"
      perform(:get, path, nil, request_headers)
    end

    def get_prescriptions_by_date(patient_id:, start_date:, end_date:)
      path = "#{config.base_path}medications?patientId=#{patient_id}&startDate=#{start_date}&endDate=#{end_date}"
      perform(:get, path, nil, request_headers)
    end

    def refill_prescription_orders(request_body)
      path = "#{config.base_path}medications/rx/refill"
      perform(:post, path, request_body.to_json, request_headers(include_content_type: true))
    end

    def get_avs(patient_id:, appt_id:)
      path = "#{config.base_path}appointments/#{appt_id}/avs?patientId=#{patient_id}"
      perform(:get, path, nil, request_headers)
    end

    def get_ccd(patient_id:, start_date:, end_date:)
      path = "#{config.base_path}ccd/oracle-health"
      params = { patientId: patient_id, startDate: start_date, endDate: end_date }
      perform(:get, path, params, request_headers)
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

    def request_headers(include_content_type: false)
      headers = {
        'Authorization' => fetch_access_token,
        'x-api-key' => config.x_api_key
      }
      headers['Content-Type'] = 'application/json' if include_content_type
      headers
    end
  end
end
