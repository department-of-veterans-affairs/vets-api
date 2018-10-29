# frozen_string_literal: true

module Common
  module Client
    module Middleware
      module Response
        class PPMSParser < Faraday::Response::Middleware
          def on_complete(env)
            env.body = parse_body(env)
            env.body = [] if env.body.nil?
          end

          private

          def parse_body(env)
            hash = JSON.parse(env.body)
            # flag Not Found errors as success so the error doesn't bubble up
            if hash['error'] && hash['error']['message'] && hash['error']['message'] =~ /No Providers found/
              env[:status] = 200
              return []
            end
            hash['value']
          end
        end
      end
    end
  end
end
Faraday::Response.register_middleware ppms_parser: Common::Client::Middleware::Response::PPMSParser
