# frozen_string_literal: true

require 'common/client/concerns/monitoring'
require 'common/client/concerns/service_errors'

module Appeals
  class Service < Common::Client::Base
    include Common::Client::Monitoring
    include Common::Client::ServiceErrors

    configuration Appeals::Configuration

    STATSD_KEY_PREFIX = 'api.appeals'

    def get_appeals(user)
      with_monitoring do
        raw_response = perform(:get, '', {}, request_headers(user))

        appeal_series = raw_response&.body&.dig(:data)
        appeal_series.map! { |a| Appeals::Models::AppealSeries.new(a[:attributes]) }

        Appeals::Responses::GetAppealsResponse.new(
          status: raw_response.status,
          appeal_series: Common::Collection.new(
            Appeals::Models::AppealSeries,
            data: appeal_series
          )
        )
      end
    rescue Common::Client::Errors::ClientError => error
      handle_service_error(error)
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
