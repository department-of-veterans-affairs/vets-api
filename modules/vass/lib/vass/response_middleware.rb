# frozen_string_literal: true

# NOTE: This require is needed for when the file is loaded directly (e.g., in specs).
# The initializer also requires this file, which happens after Rails boot.
require 'common/exceptions'
require 'vass/errors'

module Vass
  ##
  # Faraday response middleware that handles VASS API's non-standard error responses.
  #
  # VASS API returns HTTP 200 for both successful and error responses. Errors are
  # indicated by "success": false in the JSON response body. This middleware intercepts
  # these responses and raises appropriate exceptions based on the error message.
  #
  # @example Error response from VASS
  #   {
  #     "success": false,
  #     "message": "Provided veteranId does not have a valid GUID format",
  #     "data": null,
  #     "correlationId": "req123",
  #     "timeStamp": "2025-12-01T20:40:00Z"
  #   }
  #
  # Similar patterns in vets-api:
  # - EVSS::ErrorMiddleware - checks success field and messages array in 200 responses
  # - Preneeds::Middleware::Response::EoasXmlErrors - checks returnCode in 200 responses
  #
  class ResponseMiddleware < Faraday::Middleware
    # Error pattern mapping for VASS API error messages to HTTP status codes
    ERROR_PATTERNS = [
      { pattern: /missing parameter/i, status: 400 },
      { pattern: /guid.*format/i, status: 422 }, # Matches both "valid GUID format" and "invalid GUID format"
      { pattern: /invalid.*format/i, status: 422 },
      { pattern: /not found/i, status: 404 },
      { pattern: /does not exist/i, status: 404 },
      { pattern: /search miss/i, status: 404 },
      { pattern: /not available/i, status: 422 },
      { pattern: /unavailable/i, status: 422 },
      { pattern: /invalid.*date/i, status: 422 },
      { pattern: /date.*invalid/i, status: 422 },
      { pattern: /date.*range/i, status: 422 }, # Matches "date range" error messages
      { pattern: /end date.*start date/i, status: 422 }, # Matches "end date must be later than start date"
      { pattern: /invalid.*booking.*period/i, status: 422 },
      { pattern: /error loading/i, status: 502 },
      { pattern: /processor error/i, status: 502 }
    ].freeze
    ##
    # Called after the response is complete. Checks for VASS error responses
    # that return HTTP 200 with success: false.
    #
    # @param env [Faraday::Env] The Faraday environment object
    # @raise [Vass::ServiceException] When success is false
    #
    def on_complete(env)
      return unless env.status == 200
      return unless json_response?(env)

      body = env.body
      return unless body.is_a?(Hash)
      return unless body['success'] == false

      # Log to Sentry with safe context (no PHI)
      Sentry.set_extras(
        vass_error: true,
        correlation_id: body['correlation_id'],
        timestamp: body['time_stamp'],
        has_message: body['message'].present?
      )

      # Map error message to appropriate HTTP status code
      status = map_error_to_status(body['message'])

      # Log StatsD metric for HTTP 200 errors
      StatsD.increment('api.vass.http_200_errors',
                       tags: ["error_status:#{status}", 'service:vass'])

      # Raise exception with mapped status for proper error handling
      raise Vass::ServiceException.new(
        Vass::Errors::ERROR_KEY_VASS_ERROR,
        response_values(body),
        status,
        body
      )
    end

    private

    ##
    # Checks if the response is JSON content type.
    #
    # @param env [Faraday::Env] The Faraday environment object
    # @return [Boolean] true if response is JSON
    #
    def json_response?(env)
      content_type = env.response_headers['content-type']
      content_type&.downcase&.include?('json')
    end

    ##
    # Maps VASS error messages to appropriate HTTP status codes.
    # Uses ERROR_PATTERNS constant to match messages against known patterns.
    # This allows existing error handlers to properly categorize errors.
    #
    # @param message [String] The error message from VASS
    # @return [Integer] HTTP status code
    #
    def map_error_to_status(message)
      return 502 if message.blank?

      # Find first matching pattern and return its status code, default to 502
      ERROR_PATTERNS.find { |rule| message.match?(rule[:pattern]) }&.dig(:status) || 502
    end

    ##
    # Extracts response values for exception details.
    #
    # @param body [Hash] The response body
    # @return [Hash] Response values for exception
    #
    def response_values(body)
      {
        message: body['message'],
        correlation_id: body['correlation_id'],
        timestamp: body['time_stamp']
      }
    end
  end

  # Main service exception used by middleware and client
  # Inherits from BackendServiceException to maintain compatibility with vets-api error handling
  # Defined here (after common/exceptions is required) rather than in errors.rb to avoid load order issues
  class ServiceException < Common::Exceptions::BackendServiceException; end
end
