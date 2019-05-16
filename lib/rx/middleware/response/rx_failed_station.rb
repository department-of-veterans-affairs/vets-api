# frozen_string_literal: true

module Rx
  module Middleware
    module Response
      ##
      # Middleware class responsible for logging Rx Failed Station messages to Sentry
      #
      class RxFailedStation < Faraday::Response::Middleware
        include SentryLogging
        ##
        # Override the Faraday #on_complete method to log Rx failed station message to Sentry
        # @param env [Faraday::Env] the request environment
        # @return [Faraday::Env]
        #
        def on_complete(env)
          return unless env.body.is_a? Hash

          station_list = env.body.try(:[], :metadata).try(:[], :failed_station_list)
          return if station_list.blank?

          message = "Warning: prescription failed station list is not empty, '#{station_list}'"
          log_message_to_sentry(message, :warn)
        end
      end
    end
  end
end

Faraday::Response.register_middleware rx_failed_station: Rx::Middleware::Response::RxFailedStation
