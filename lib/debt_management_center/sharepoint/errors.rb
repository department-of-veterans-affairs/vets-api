# frozen_string_literal: true

module DebtManagementCenter
  module Sharepoint
    class Errors < Faraday::Middleware
      def on_complete(env)
        return if env.success?

        Rails.logger.error("Debt Management Center Sharepoint failed path: #{env.url.path[%r{.*/Web/[^/]+}]}")
        response_values = { status: env.status, detail: env.reason_phrase, source: 'SharepointRequest' }
        case env.status
        when 400..499
          raise Common::Exceptions::BackendServiceException.new(
            'SHAREPOINT_400', response_values.merge(code: 'SHAREPOINT_400'), env.status, env.body
          )
        when 500..510
          raise Common::Exceptions::BackendServiceException.new(
            'SHAREPOINT_502', response_values.merge(code: 'SHAREPOINT_502'), env.status, env.body
          )
        else
          raise Common::Exceptions::BackendServiceException.new(
            'SHAREPOINT_UNKNOWN', response_values.merge(code: 'SHAREPOINT_UNKNOWN'), env.status, env.body
          )
        end
      end
    end
  end
end
