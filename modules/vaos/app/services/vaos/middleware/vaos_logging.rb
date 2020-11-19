# frozen_string_literal: true

module VAOS
  module Middleware
    ##
    # Faraday middleware that logs various semantically relevant attributes needed for debugging and audit purposes
    #
    class VAOSLogging < Faraday::Middleware
      def initialize(app)
        super(app)
      end

      # #call
      #
      # Logs all outbound request / responses to VAMF api gateway as :info when success and :warn when fail
      #
      # Semantic logging tags:
      # jti: The "jti" (JWT ID) claim provides a unique identifier for the JWT.
      # status: The HTTP status returned from upstream.
      # duration: The amount of time it took between request being made and response being received in seconds.
      # url: The HTTP Method and URL invoked in the request.
      #
      # @param env [Faraday::Env] the request/response tree
      # @return [Faraday::Env]
      def call(env)
        start_time = Time.current

        @app.call(env).on_complete do |response_env|
          log_tags = {
            jti: jti(env),
            status: response_env.status,
            duration: Time.current - start_time,
            # service_name: service_name || 'VAOS Generic', # Need to figure out a clean way to do this with headers
            url: "(#{env.method.upcase}) #{env.url}"
          }

          if response_env.status.between?(200, 299)
            log(:info, 'VAOS service call succeeded!', log_tags)
          else
            log(:warn, 'VAOS service call failed!', log_tags)
          end
        end
      end

      private

      # #log invokes the Rails.logger
      #
      # @param type [Symbol] one of [:info, :warn]
      # @param message [String] the string you would like to appear in logs
      # @param tags [Hash] key value pairs of semantically relevant tags needed for debugging
      # @return [Boolean] returns true or false
      def log(type, message, tags)
        Rails.logger.send(type, message, tags)
      end

      # #decode_jwt_no_sig_check decodes the JWT token received in the response without signature verification
      #
      # @param token [String] The JWT token received in the response
      # @return [Hash] returns a JSON Hash object corresponding to JWT specification
      def decode_jwt_no_sig_check(token)
        JWT.decode(token, nil, false).first
      end

      # #user_session_request? determines if current request is a user session request
      #
      # @return [Boolean] true if user session request, false otherwise
      def user_session_request?(env)
        env.url.to_s.include?('users/v2/session?processRules=true') ? true : false
      end

      # #jti is the value from the JWT key value pair in the response and needed for logging and audit purposes
      #
      # @param env [Faraday::Env] The Request/Response tree object
      # @return [String] The JTI value or "unknown jti" if a parsing or other error is encountered (failing gracefully)
      def jti(env)
        if user_session_request?(env)
          decode_jwt_no_sig_check(env.body)['jti']
        else
          decode_jwt_no_sig_check(x_vamf_headers(env.request_headers))['jti']
        end
      rescue
        'unknown jti'
      end

      # #x_vamf_headers identifies which X-Vamf-Header was set and returns the appropriate header value
      #
      # @param request_headers The set of request headers
      # @return [String] the JWT set in the request headers
      def x_vamf_headers(request_headers)
        request_headers['X-Vamf-Jwt'] || request_headers['X-VAMF-JWT']
      end
    end
  end
end

Faraday::Middleware.register_middleware vaos_logging: VAOS::Middleware::VAOSLogging
