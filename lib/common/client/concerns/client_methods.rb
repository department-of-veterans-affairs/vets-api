module Common
  module Client
    module ClientMethods
      extend ActiveSupport::Concern

      private

      def perform(method, path, params, headers = nil)
        raise NoMethodError, "#{method} not implemented" unless config.request_types.include?(method)

        send(method, path, params || {}, headers)
      end

      def request(method, path, params = {}, headers = {})
        raise_not_authenticated if headers.keys.include?('Token') && headers['Token'].nil?
        connection.send(method.to_sym, path, params) { |request| request.headers.update(headers) }.env
      rescue Faraday::Error::TimeoutError, Timeout::Error => error
        raise Common::Client::Errors::RequestTimeout, error
      rescue Faraday::Error::ClientError => error
        raise Common::Client::Errors::Client, error
      end

      def get(path, params, headers = base_headers)
        request(:get, path, params, headers)
      end

      def post(path, params, headers = base_headers)
        request(:post, path, params, headers)
      end

      def patch(path, params, headers = base_headers)
        request(:patch, path, params, headers)
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


      def configuration_and_session_namespace
        self.class.name.to_s.split("::")[0..-2].join("::")
      end

      def namespaced(class_name)
        "#{configuration_and_session_namespace}::#{class_name}".safe_constantize
      end
    end
  end
end
