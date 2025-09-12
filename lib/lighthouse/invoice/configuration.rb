# frozen_string_literal: true

require 'common/client/configuration/rest'
require 'common/client/middleware/response/raise_custom_error'
require 'lighthouse/auth/client_credentials/jwt_generator'
require 'lighthouse/auth/client_credentials/service'

module Lighthouse
  module Invoice
    class Configuration < Common::Client::Configuration::REST
      SETTINGS = Settings.lighthouse.invoice

      def path_join(*paths)
        paths.reduce('') do |acc, p|
          trimmed_slash = p.gsub(%r{(^/+|/+$)}, '')
          acc + "#{trimmed_slash}/"
        end.chop!
      end

      def invoice_url
        URI path_join(SETTINGS.url, SETTINGS.path)
      end

      def service_name
        'Lighthouse_Invoice'
      end

      def connection
        @conn ||= Faraday.new(invoice_url, headers: base_request_headers, request: request_options) do |faraday|
          faraday.use(:breakers, service_name:)
          faraday.use Faraday::Response::RaiseError
        end
      end
    end
  end
end
