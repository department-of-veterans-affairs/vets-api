module Common
  module Client
    module Middleware
      module Response
        class Snakecase < Faraday::Response::Middleware
          def on_complete(env)
            return unless env.response_headers['content-type'] =~ /\bjson/
            if env[:body].is_a?(Hash)
              env[:body] = snakecase(env[:body])
            end
          end

          private

          def snakecase(parsed_json)
            case parsed_json
            when Array
              parsed_json.map { |hash| underscore_symbolize(hash) }
            when Hash
              underscore_symbolize(parsed_json)
            end
          end

          def underscore_symbolize(hash)
            hash.deep_transform_keys { |k| k.underscore.to_sym }
          end
        end
      end
    end
  end
end

Faraday::Response.register_middleware snakecase: Common::Client::Middleware::Response::Snakecase
