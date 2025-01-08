# frozen_string_literal: true

require 'common/client/concerns/mhv_locked_session_client'

module Common
  module Client
    module Concerns
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
        include MhvLockedSessionClient
        include SentryLogging

        attr_reader :session

        def user_key
          session.user_id
        end

        def invalid?(session)
          session.expired?
        end

        def session_config_key
          :mhv_session_lock
        end

        ##
        # Creates a session from the request headers
        #
        # @return [Rx::ClientSession] if an Rx (Prescription) client session
        # @return [SM::ClientSession] if a SM (Secure Messaging) client session
        #
        def get_session
          env = get_session_tagged
          req_headers = env.request_headers
          res_headers = env.response_headers
          new_session = @session.class.new(user_id: req_headers['mhvCorrelationId'],
                                           expires_at: res_headers['expires'],
                                           token: res_headers['token'])
          new_session.save
          new_session
        end

        private

        def get_session_tagged
          Sentry.set_tags(error: 'mhv_session')
          env = perform(:get, 'session', nil, auth_headers)
          puts "MHV SESSION ENV: #{env.inspect}"
          Sentry.get_current_scope.tags.delete(:error)
          env
        end

        def token_headers
          config.base_request_headers.merge('Token' => session.token)
        end

        def auth_headers
          config.base_request_headers.merge('appToken' => config.app_token, 'mhvCorrelationId' => session.user_id.to_s)
        end
      end
    end
  end
end
