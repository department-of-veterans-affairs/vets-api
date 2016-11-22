# frozen_string_literal: true
module Common
  module Client
    module Middleware
      module Response
        class Snakecase < Faraday::Response::Middleware
          def on_complete(env)
            return unless env.response_headers['content-type'] =~ /\bjson/
            env.body = parse(env.body)
          end

          def parse(parsed_json)
            case parsed_json
            when Array
              parsed_json.map { |hash| underscore_symbolize(hash) }
            when Hash
              underscore_symbolize(parsed_json)
            end
          end

          private

          def underscore_symbolize(hash)
            hash.deep_transform_keys { |k| k.underscore.to_sym }
          end
        end

        class SnakecaseString < Snakecase
          private

          def underscore_symbolize(hash)
            hash.deep_transform_keys(&:underscore)
          end
        end
      end
    end
  end
end

Faraday::Response.register_middleware snakecase: Common::Client::Middleware::Response::Snakecase
Faraday::Response.register_middleware snakecase_string: Common::Client::Middleware::Response::SnakecaseString
