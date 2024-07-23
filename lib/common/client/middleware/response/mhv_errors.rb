# frozen_string_literal: true

module Common
  module Client
    module Middleware
      module Response
        ##
        # Faraday response middleware that checks the MHV service response for errors
        #
        class MHVErrors < Faraday::Middleware
          ##
          # Checks the response for errors
          #
          # @return [Faraday::Env]
          #
          def on_complete(env)
            return if env.success?
            return unless env[:body].is_a?(Hash)

            env[:body]['code'] = env[:body].delete('errorCode')
            env[:body]['detail'] = env[:body].delete('message')
            env[:body]['source'] = env[:body].delete('developerMessage')
          end
        end
      end
    end
  end
end

Faraday::Response.register_middleware mhv_errors: Common::Client::Middleware::Response::MHVErrors
