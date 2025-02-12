# frozen_string_literal: true
require 'common/client/configuration/rest'
require 'common/client/middleware/request/camelcase'
require 'common/client/middleware/response/json_parser'
require 'common/client/middleware/response/raise_custom_error'
require 'common/client/middleware/response/mhv_errors'
require 'common/client/middleware/response/snakecase'
require 'faraday/multipart'

module UnifiedHealthData
  class Configuration < Common::Client::Configuration::REST
    def settings
      Settings.mhv.uhd
    end

    def base_path
      "#{settings.host}/mhvapi/v1/medicalrecords/"
    end

    def service_name
      'UnifiedHealthData'
    end

    def token_path
      "#{settings.security_host}/mhvapi/security/v1/login"
    end

    def app_id
      settings.app_id
    end

    def app_token
      settings.app_token
    end

    def connection
      Faraday.new(base_path) do |conn|
        conn.request :json
        conn.response :json

        # Uncomment this if you want curl command equivalent or response output to log
        # conn.request(:curl, ::Logger.new($stdout), :warn) unless Rails.env.production?
        # conn.response(:logger, ::Logger.new($stdout), bodies: true) unless Rails.env.production?

        conn.response :raise_custom_error
        conn.adapter Faraday.default_adapter
      end
    end

  end
end
