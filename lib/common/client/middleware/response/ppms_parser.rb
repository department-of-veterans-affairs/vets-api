# frozen_string_literal: true

module Common
  module Client
    module Middleware
      module Response
        class PPMSParser < Faraday::Middleware
          def on_complete(env)
            env.body = parse_body(env)
          end

          private

          def parse_body(env)
            hash = JSON.parse(env.body)
            msg = hash.dig('error', 'message')

            case msg
            when /No Providers found/ # flag Not Found errors as success so the error doesn't bubble up
              env[:status] = 200
              return []
            when /An error has occurred/ # PPMS has encountered an internal error
              hash['error']['code'] = '_502' if hash['error']['code'].blank? # Set code so matches in exceptions.en.yml
              hash['error']['detail'] = hash['error']['message']
              return hash['error']
            end
            hash['value']
          end
        end
      end
    end
  end
end

Faraday::Response.register_middleware ppms_parser: Common::Client::Middleware::Response::PPMSParser
