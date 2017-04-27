# frozen_string_literal: true
require 'appeals_status/models/appeals'
require 'appeals_status/responses/get_appeals_response'

module AppealStatus
  class Service
    def get_appeals(user)
      response = try_mocks(:mocked_get_appeals_responses, user, AppealStatus::Responses::GetAppealsResponse)
      # response ||= make_the_actual_request
      response
    end

    protected

    def mocked_get_appeals_responses
      @mocked_get_appeals_responses ||= YAML.load_file('config/appeals_status/mock_get_appeals_responses.yml')
    end

    def try_mocks(responses_method, user, response_class)
      if should_mock?
        responses = send(responses_method)
        response = responses.dig('users', user.ssn)
        if response
          appeals = AppealStatus::Models::Appeals.new(response)
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
  end
end
