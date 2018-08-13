# frozen_string_literal: true

module Common
  module Client
    module Middleware
      module Response
        class PPMSParser < Faraday::Response::Middleware
          def on_complete(env)
            env.body = parse_body(env)
          end

          private

          def parse_body(env)
            hash = JSON.parse(env.body)
            hash['value']
          end
        end
      end
    end
  end
end
Rails.logger.info('should register')
Faraday::Response.register_middleware ppms_parser: Common::Client::Middleware::Response::PPMSParser
