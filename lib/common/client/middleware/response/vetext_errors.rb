# frozen_string_literal: true

module Common
  module Client
    module Middleware
      module Response
        class VETextError < Faraday::Middleware
          def on_complete(env)
            return if env.success?

            Rails.logger.info('VEText Service Error', body: env.body, status: env.status)
            case env.status
            when 400..499
              raise Common::Exceptions::BackendServiceException.new('VETEXT_PUSH_400', {}, env.status,
                                                                    env.body)
            when 500..599
              raise Common::Exceptions::BackendServiceException.new('VETEXT_PUSH_502', {}, env.status)
            else
              raise 'Unexpected VEText Error'
            end
          end
        end
      end
    end
  end
end

Faraday::Response.register_middleware vetext_error: Common::Client::Middleware::Response::VETextError
