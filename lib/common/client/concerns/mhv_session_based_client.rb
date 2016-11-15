# frozen_string_literal: true
module Common
  module Client
    module MHVSessionBasedClient
      extend ActiveSupport::Concern

      def initialize(session:)
        @session = self.class.client_session.find_or_build(session)
      end

      attr_reader :session

      def authenticate
        if session.expired?
          @session = get_session
          @session.save
        end
        self
      end

      module ClassMethods
        def client_session(klass = nil)
          @client_session ||= klass
        end
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
