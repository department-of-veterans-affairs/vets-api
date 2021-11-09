# frozen_string_literal: true

module FacilitiesApi
  module V1
    module Lighthouse
      module Middleware
        class Errors < Faraday::Response::Middleware
          def on_complete(env)
            return if env.success?

            env.body = parse_body(env)
          end

          private

          def parse_body(env)
            body = JSON.parse(env.body)
            message = body['message']

            body['detail'] = message
            body['code'] = env.status
            body['source'] = 'Lighthouse Facilities'

            body
          end
        end
      end
    end
  end
end
Faraday::Response.register_middleware lighthouse_facilities_errors: FacilitiesApi::V1::Lighthouse::Middleware::Errors
