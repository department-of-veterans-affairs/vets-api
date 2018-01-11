# frozen_string_literal: true
require 'appeals_status/models/appeal'
require 'appeals_status/responses/get_appeals_response'

module Appeals
  class Service < Common::Client::Base
    configuration Appeals::Configuration

    def get_appeals(user)
      response = perform(:get, '', {})
      Appeals::Responses::Appeals.new(response.body, response.status)
    end

    private

    def request_headers(user)
      {
        'ssn' => user.ssn,
        'Authorization' => "Token token=#{Settings.appeals.app_token}"
      }
    end
  end
end
