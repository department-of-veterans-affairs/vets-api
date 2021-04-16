# frozen_string_literal: true

module Common
  module Client
    module Middleware
      module Response
        class VETextError < Faraday::Response::Middleware
          def on_complete(env)
            return if env.success?

            case env.status
            when 400..499
              Rails.logger.debug('VEText Service 4XX Error', body: env.body, status: env.status)
              raise Common::Exceptions::BackendServiceException.new('VETEXT_PUSH_400', {}, env.status,
                                                                    env.body)
            when 500..599
              Rails.logger.debug('VEText Service 5XX Error', body: env.body, status: env.status)
              raise Common::Exceptions::BackendServiceException.new('VETEXT_PUSH_502', {}, env.status)
            else
              Rails.logger.debug('VEText Service Unexpected Error', body: env.body, status: env.status)
              raise 'Unexpected VEText Error'
            end
          end
        end
      end
    end
  end
end

Faraday::Response.register_middleware vetext_error: Common::Client::Middleware::Response::VETextError
