# frozen_string_literal: true
require 'appeals_status/models/appeals'
require 'appeals_status/responses/get_appeals_response'

module AppealsStatus
  class Service < Common::Client::Base
    configuration AppealsStatus::Configuration

    def get_appeals(user)
      response = try_mocks(:mocked_get_appeals_responses, user, AppealsStatus::Responses::GetAppealsResponse)
      response ||= fetch_appeals(user)
      response
    end

    protected

    def mocked_get_appeals_responses
      @mocked_get_appeals_responses ||= YAML.load_file('config/appeals_status/mock_get_appeals_responses.yml')
    end

    def fetch_appeals(user)
      raw_response = perform(:get, '', {}, request_headers(user))
      AppealsStatus::Responses::GetAppealsResponse.new(
        status: raw_response.status,
        appeals: AppealsStatus::Models::Appeals.new(raw_response.body)
      )
    end

    def try_mocks(mock_responses_method, user, response_class)
      if should_mock?
        responses = send(mock_responses_method)
        response = responses.dig('users', user.ssn)
        if response
          appeals = AppealsStatus::Models::Appeals.new(response.deep_symbolize_keys)
          return response_class.new(
            status: 200,
            appeals: appeals
          )
        end
      end
      nil
    end

    def should_mock?
      [true, 'true'].include?(Settings.appeals_status.mock)
    end

    def request_headers(user)
      {
        'ssn' => user.ssn,
        'Authorization' => "Token token=#{config.app_token}"
      }
    end
  end
end
