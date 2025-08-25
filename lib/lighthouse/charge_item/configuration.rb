# frozen_string_literal: true

require 'lighthouse/charge_item/configuration'
require 'lighthouse/service_exception'
require 'common/exceptions/bad_request'

module Lighthouse
  module ChargeItem
    class Configuration < Common::Client::Configuration::REST
      SETTINGS = Settings.lighthouse.charge_item
      SCOPES = %w[charge_item.read].freeze

      def path_join(*paths)
        paths.reduce('') do |acc, p|
          trimmed_slash = p.gsub(%r{(^/+|/+$)}, '')
          acc + "#{trimmed_slash}/"
        end.chop!
      end

      def charge_item_url
        URI path_join(SETTINGS.url, SETTINGS.path)
      end

      def service_name
        'Lighthouse_ChargeItem'
      end

      def connection
        @conn ||= Faraday.new(charge_item_url, headers: base_request_headers, request: request_options) do |faraday|
          faraday.use(:breakers, service_name:)
          faraday.use Faraday::Response::RaiseError # custom error handling for 4xx and 5xx responses
        end
      end
    end
  end
end
