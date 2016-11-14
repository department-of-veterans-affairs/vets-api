# frozen_string_literal: true
require 'faraday'
require 'common/client/errors'

module Common
  module Client
    class Base
      class << self
        def configuration(configuration = nil)
          @configuration ||= configuration.instance
        end
      end

      private

      def config
        self.class.configuration
      end

      def connection
        config.connection
      end

      def perform(method, path, params, headers = nil)
        raise NoMethodError, "#{method} not implemented" unless config.request_types.include?(method)

        send(method, path, params || {}, headers)
      end

      def request(method, path, params = {}, headers = {})
        raise_not_authenticated if headers.keys.include?('Token') && headers['Token'].nil?
        connection.send(method.to_sym, path, params) { |request| request.headers.update(headers) }.env
      rescue Faraday::ClientError, Timeout::Error
        raise Common::Client::Errors::Client
      end

      def get(path, params, headers = base_headers)
        request(:get, path, params, headers)
      end

      def post(path, params, headers = base_headers)
        request(:post, path, params, headers)
      end

      def put(path, params, headers = base_headers)
        request(:put, path, params, headers)
      end

      def delete(path, params, headers = base_headers)
        request(:delete, path, params, headers)
      end

      def raise_not_authenticated
        raise Common::Client::Errors::NotAuthenticated, 'Not Authenticated'
      end
    end
  end
end
