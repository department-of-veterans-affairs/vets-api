# frozen_string_literal: true

require 'res/configuration'
require 'common/client/base'

# The RES::Service class is where we keep RES related endpoint calls and common methods
module RES
  class Service < Common::Client::Base
    include Common::Client::Concerns::Monitoring

    def send_to_res(payload:)
      with_monitoring do
        perform(
          :post,
          end_point,
          payload,
          request_headers
        ) # see lib/common/client/base.rb#L94
      end
    end

    def request_headers
      {
        'Appian-API-Key': Settings.res.api_key
      }
    end

    private

    def end_point
      "#{Settings.res.base_url}/suite/webapi/form281900"
    end
  end
end
