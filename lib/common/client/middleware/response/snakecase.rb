module Common
  module Client
    module Middleware
      module Response
        class Snakecase < Faraday::Response::Middleware

          def on_complete(env)
            if env.response_headers['content-type'] =~ /\bjson/
              env.body = parse(env.body)
            end
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
      end
    end
  end
end

Faraday::Response.register_middleware snakecase: Common::Client::Middleware::Response::Snakecase
