# frozen_string_literal: true

module FacilitiesApi
  module V2
    module Lighthouse
      module Middleware
        class Errors < Faraday::Middleware
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
          rescue JSON::ParserError
            {
              'detail' => 'Unexpected response from Lighthouse Facilities',
              'code' => env.status,
              'source' => 'Lighthouse Facilities'
            }
          end
        end
      end
    end
  end
end
Faraday::Response.register_middleware lighthouse_facilities_errors: FacilitiesApi::V2::Lighthouse::Middleware::Errors
