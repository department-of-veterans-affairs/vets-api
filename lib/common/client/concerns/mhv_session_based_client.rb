# frozen_string_literal: true

module Common
  module Client
    ##
    # Module mixin for overriding session logic when making MHV client connections
    #
    # @see BB::Client
    # @see Rx::Client
    # @see SM::Client
    # @see MHVLogging::Client
    #
    # @!attribute [r] session
    #   @return [Hash] a hash containing session information
    #
    module MHVSessionBasedClient
      extend ActiveSupport::Concern

      ##
      # @param session [Hash] a hash containing user_id with which the session will be found or built
      #
      def initialize(session:)
        @session = self.class.client_session.find_or_build(session)
      end

      attr_reader :session

      ##
      # Ensures the MHV based session is not expired
      #
      # @return [MHVSessionBasedClient] instance of `self`
      #
      def authenticate
        if session.expired?
          @session = get_session
          @session.save
        end
        self
      end

      ##
      # Creates a session from the request headers
      #
      # @return [Rx::ClientSession] if an Rx (Prescription) client session
      # @return [Sm::ClientSession] if a SM (Secure Messaging) client session
      #
      def get_session
        env = perform(:get, 'session', nil, auth_headers)
        req_headers = env.request_headers
        res_headers = env.response_headers
        @session.class.new(user_id: req_headers['mhvCorrelationId'],
                           expires_at: res_headers['expires'],
                           token: res_headers['token'])
      end

      ##
      # Override client_session method to use extended ::ClientSession classes
      #
      module ClassMethods
        ##
        # @return [Rx::ClientSession] if an Rx (Prescription) client session
        # @return [Sm::ClientSession] if a SM (Secure Messaging) client session
        #
        def client_session(klass = nil)
          @client_session ||= klass
        end
      end

      private

      def token_headers
        config.base_request_headers.merge('Token' => session.token)
      end

      def auth_headers
        config.base_request_headers.merge('appToken' => config.app_token, 'mhvCorrelationId' => session.user_id.to_s)
      end
    end
  end
end
