# frozen_string_literal: true

require 'vre/configuration'
require 'common/client/base'

# The VRE::Service class is where we keep VRE related endpoint calls and common methods
module VRE
  class Service < Common::Client::Base
    include Common::Client::Concerns::Monitoring

    def send_to_vre(payload:)
      with_monitoring do
        perform(
          :post,
          end_point,
          payload,
          request_headers
        ) # see lib/common/client/base.rb#L94
      end
    rescue Common::Client::Errors::ClientError => e
      log_message_to_sentry(
        "VRE form submission failed with http status: #{e.status}",
        :error,
        { message: e.message, status: e.status, body: e.body },
        { team: 'vfs-ebenefits' }
      )
      raise e
    end

    def request_headers
      {
        'Appian-API-Key': Settings.veteran_readiness_and_employment.api_key
      }
    end

    private

    def end_point
      "#{Settings.veteran_readiness_and_employment.base_url}/suite/webapi/form281900"
    end
  end
end
