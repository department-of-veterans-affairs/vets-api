# frozen_string_literal: true

require 'appeals_status/models/appeal'
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
      formatted_response = format_response_reasonably(raw_response.body)
      AppealsStatus::Responses::GetAppealsResponse.new(
        status: raw_response.status,
        appeals: Common::Collection.new(AppealsStatus::Models::Appeal, data: formatted_response)
      )
    end

    def try_mocks(mock_responses_method, user, response_class)
      if should_mock?
        responses = send(mock_responses_method)
        response = responses.dig('users', user.ssn)
        if response
          formatted_response = format_response_reasonably(response)
          appeals = Common::Collection.new(
            AppealsStatus::Models::Appeal,
            data: formatted_response
          )
          return response_class.new(
            status: 200,
            appeals: appeals
          )
        end
      end
      nil
    end

    def format_response_reasonably(response)
      response = response.deep_symbolize_keys
      format_hearings_reasonably(response)
      response[:data].each do |appeal|
        appeal[:events] = appeal[:attributes].delete(:events)
        appeal[:attributes].each do |k, v|
          appeal[k] = v
        end
        appeal.delete(:attributes)
        appeal.delete(:relationships)
      end
      response[:data]
    end

    def format_hearings_reasonably(response)
      hearings = response[:included]
      if hearings.present?
        response[:data].each do |appeal|
          appeal[:hearings] = appeal[:relationships][:scheduled_hearings][:data].map do |rel|
            hearings.find { |h| h[:id] == rel[:id] }.tap do |hearing|
              hearing[:attributes].each do |k, v|
                hearing[k] = v
              end
              hearing.delete(:attributes)
            end
          end
        end
      end
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
