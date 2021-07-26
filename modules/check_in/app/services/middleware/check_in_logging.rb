# frozen_string_literal: true

module Middleware
  ##
  # Faraday middleware that logs various semantically relevant attributes needed for debugging and audit purposes
  #
  class CheckInLogging < Faraday::Middleware
    def initialize(app) # rubocop:disable Lint/UselessMethodDefinition
      super(app)
    end

    # #call
    #
    # Logs all outbound token request / responses to the CHIP API as :info when success and :warn when fail
    #
    # Semantic logging tags:
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
          status: response_env.status,
          duration: Time.current - start_time,
          url: "(#{env.method.upcase}) #{env.url}"
        }

        if response_env.status.between?(200, 299)
          log(:info, 'CheckIn service call succeeded!', log_tags)
        else
          log(:warn, 'CheckIn service call failed!', log_tags)
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
  end
end
