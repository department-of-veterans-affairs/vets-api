# frozen_string_literal: true

module Common
  module Middleware
    ##
    # Base Faraday middleware that logs various semantically relevant attributes needed for debugging and audit purposes
    #
    class BaseLogging < Faraday::Middleware
      # #call
      #
      # Logs all outbound request / responses to VAMF api gateway as :info when success and :warn when fail
      #
      # Semantic logging tags:
      #   jti: The "jti" (JWT ID) claim provides a unique identifier for the JWT.
      #   status: The HTTP status returned from upstream.
      #   duration: The amount of time it took between request being made and response being received in seconds.
      #   url: The HTTP Method and URL invoked in the request.
      #
      # @param env [Faraday::Env] the request/response tree
      # @return [Faraday::Env]
      def call(env)
        statsd_increment("#{statsd_key_prefix}.total", env)
        start_time = Time.current

        @app.call(env).on_complete do |response_env|
          if response_env.status.between?(200, 299)
            log(:info, "#{service_name} service call succeeded!", log_tags(env, start_time, response_env))
          elsif response_env.status == 400 # 400 error resp at times contain PII/PHI so we don't want the err msg logged
            statsd_increment("#{statsd_key_prefix}.fail", env)
            log(:warn, "#{service_name} service call failed!", log_tags(env, start_time, response_env))
          else
            statsd_increment("#{statsd_key_prefix}.fail", env)
            log(:warn, "#{service_name} service call failed!", log_error_tags(env, start_time, response_env))
          end
        end
      rescue Timeout::Error, Faraday::TimeoutError, Faraday::ConnectionFailed => e
        statsd_increment("#{statsd_key_prefix}.fail", env, e)
        log(:warn, "#{service_name} service call failed - #{e.message}", log_tags(env, start_time))
        raise
      end

      private

      # Returns the configuration for the service. Must be implemented by subclasses.
      # @raise [NotImplementedError] if not implemented by subclass
      # @return [Object] a configuration object responding to #service_name
      def config
        raise NotImplementedError, 'Subclasses must implement #config'
      end

      # Returns the service name extracted from the configuration.
      # @return [String] the service name
      def service_name
        config.service_name
      end

      # Returns the StatsD key prefix for the service. Must be implemented by subclasses.
      # @raise [NotImplementedError] if not implemented by subclass
      # @return [String] the StatsD key prefix
      def statsd_key_prefix
        raise NotImplementedError, 'Subclasses must implement #statsd_key_prefix'
      end

      # Builds a hash of logging tags for a request/response.
      #
      # @param env [Faraday::Env] the request environment
      # @param start_time [Time] the time when the request was initiated
      # @param response_env [Faraday::Env, nil] the response environment
      # @return [Hash] a hash containing logging tags
      def log_tags(env, start_time, response_env = nil)
        anon_uri = VAOS::Anonymizers.anonymize_uri_icn(env.url)
        {
          jti: jti(env),
          status: response_env&.status,
          duration: Time.current - start_time,
          service_name: config.service_name,
          url: "(#{env.method.upcase}) #{anon_uri}"
        }
      end

      # Builds a hash of logging tags for error responses, including the error message.
      #
      # @param env [Faraday::Env] the request environment
      # @param start_time [Time] the time when the request was initiated
      # @param response_env [Faraday::Env] the response environment
      # @return [Hash] a hash containing logging tags with error info
      def log_error_tags(env, start_time, response_env)
        tags = log_tags(env, start_time, response_env)
        tags.merge(vamf_msg: response_env&.body)
      end

      # Increments a StatsD metric for the given key using request details.
      #
      # @param key [String] the StatsD metric key
      # @param env [Faraday::Env] the request environment
      # @param error [Exception, nil] an optional error object
      # @return [void]
      def statsd_increment(key, env, error = nil)
        StatsDMetric.new(key:).save
        tags = [
          "method:#{env.method.upcase}",
          "url:#{StringHelpers.filtered_endpoint_tag(env.url.path)}",
          "http_status:#{error.present? ? error.class : env.status}"
        ]
        StatsD.increment(key, tags:)
      end

      # Logs a message using Rails.logger with the given type and tags.
      #
      # @param type [Symbol] one of [:info, :warn]
      # @param message [String] the string you would like to appear in logs
      # @param tags [Hash] key value pairs of semantically relevant tags needed for debugging
      # @return [Boolean] returns true or false
      def log(type, message, tags)
        Rails.logger.send(type, message, **tags)
      end

      # Decodes a JWT token without verifying its signature.
      #
      # @param token [String] The JWT token received in the response
      # @return [Hash] returns a JSON Hash object corresponding to JWT specification
      def decode_jwt_no_sig_check(token)
        JWT.decode(token, nil, false).first
      end

      # Extracts the "jti" (JWT ID) claim from the request or response.
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

      # Determines if the current request is a user session request.
      #
      # @param env [Faraday::Env] the request/response environment
      # @return [Boolean] true if it is a user session request, false otherwise
      def user_session_request?(env)
        env.url.to_s.include?('users/v2/session?processRules=true')
      end

      # Extracts the JWT from the X-Vamf-Header in the request headers.
      #
      # @param request_headers The set of request headers
      # @return [String] the JWT set in the request headers
      def x_vamf_headers(request_headers)
        request_headers['X-Vamf-Jwt'] || request_headers['X-VAMF-JWT']
      end
    end
  end
end
