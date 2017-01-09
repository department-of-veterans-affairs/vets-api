# frozen_string_literal: true
require 'faraday'
require 'common/client/errors'
require 'common/models/collection'

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

      # memoize the connection from config
      def connection
        @connection ||= config.connection
      end

      def perform(method, path, params, headers = nil)
        raise NoMethodError, "#{method} not implemented" unless config.request_types.include?(method)

        send(method, path, params || {}, headers)
      end

      def request(method, path, params = {}, headers = {})
        raise_not_authenticated if headers.keys.include?('Token') && headers['Token'].nil?
        binding.pry
        connection.send(method.to_sym, path, params) { |request| request.headers.update(headers) }.env
      rescue Faraday::ClientError, Timeout::Error
        raise Common::Client::Errors::ClientError
      end

      def get(path, params = nil, headers = nil)
        request(:get, path, params || {}, headers || {})
      end

      def post(path, params = nil, headers = nil)
        request(:post, path, params || {}, headers || {})
      end

      def put(path, params = nil, headers = nil)
        request(:put, path, params || {}, headers || {})
      end

      def delete(path, params = nil, headers = nil)
        request(:delete, path, params || {}, headers || {})
      end

      def raise_not_authenticated
        raise Common::Client::Errors::NotAuthenticated, 'Not Authenticated'
      end
    end
  end
end
