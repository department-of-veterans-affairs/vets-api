# frozen_string_literal: true

module Common
  module Client
    module Middleware
      module Response
        class JsonParser < Faraday::Response::Middleware
          WHITESPACE_REGEX = /\A^\s*$\z/
          MHV_SUCCESS_REGEX = /^success/i
          UNPARSABLE_STATUS_CODES = [204, 301, 302, 304].freeze

          def on_complete(env)
            if env.response_headers['content-type']&.match?(/\bjson/)
              if env.body =~ WHITESPACE_REGEX || env.body =~ MHV_SUCCESS_REGEX
                env.body = ''
              else
                env.body = parse(env.body) unless UNPARSABLE_STATUS_CODES.include?(env[:status])
              end
            end
          end

          def parse(body = nil)
            Oj.load(body)
          rescue Oj::Error => e
            raise Common::Client::Errors::Serialization, e
          end
        end
      end
    end
  end
end

Faraday::Response.register_middleware json_parser: Common::Client::Middleware::Response::JsonParser
