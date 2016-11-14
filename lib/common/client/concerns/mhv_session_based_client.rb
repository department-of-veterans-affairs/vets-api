# frozen_string_literal: true
require 'common/client/concerns/client_methods'

module Common
  module Client
    module MHVSessionBasedClient
      extend ActiveSupport::Concern

      included do
        include Common::Client::ClientMethods
      end

      attr_reader :session

      def initialize(session: )
        @session = namespaced('ClientSession').find_or_build(session)
      end

      def config
        namespaced('Configuration').instance
      end

      def authenticate
        if session.expired?
          @session = get_session
          @session.save
        end
        self
      end

      private

      def auth_headers
        config.base_request_headers.merge('appToken' => config.app_token, 'mhvCorrelationId' => session.user_id.to_s)
      end

      def token_headers
        config.base_request_headers.merge('Token' => session.token)
      end
    end
  end
end
