# frozen_string_literal: true

require 'common/client/configuration/rest'
require 'common/client/middleware/response/raise_custom_error'

module MailAutomation
  class Configuration < Common::Client::Configuration::REST
    self.open_timeout = Settings.mail_automation&.open_timeout || 15
    self.read_timeout = Settings.mail_automation&.read_timeout || 75

    def base_path
      Settings.mail_automation.url
    end

    def service_name
      'MasNotificationClient'
    end

    def connection
      Faraday.new(base_path, headers: base_request_headers, request: request_options) do |faraday|
        faraday.use(:breakers, service_name:)
        faraday.use Faraday::Response::RaiseError

        # Uncomment this if you want curl command equivalent or response output to log
        # faraday.request(:curl, ::Logger.new($stdout), :warn) unless Rails.env.production?
        # faraday.response(:logger, ::Logger.new($stdout), bodies: true) unless Rails.env.production?

        faraday.response :json
        faraday.adapter Faraday.default_adapter
      end
    end
  end
end
