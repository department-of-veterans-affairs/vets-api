# frozen_string_literal: true

module FacilitiesApi
  module V1
    module PPMS
      module Middleware
        class PPMSParser < Faraday::Response::Middleware
          def on_complete(env)
            env.body = parse_body(env)
          end

          private

          def parse_body(env)
            hsh = JSON.parse(env.body)

            if hsh['error'] && hsh['error']['message'].match?(/No Providers found/)
              env[:status] = 200
              []
            elsif hsh['error']
              hsh['error']['code'] = '_502' if hsh['error']['code'].blank? # Set code so matches in exceptions.en.yml
              hsh['error']['detail'] = hsh['error']['message']
              hsh['error']['source'] = hsh.dig('error', 'innererror', 'message')
              hsh['error']
            else
              hsh['value']
            end
          end
        end
      end
    end
  end
end
