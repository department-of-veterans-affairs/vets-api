module Common
  module Client
    module Middleware
      module Request
        class Camelcase < Faraday::Response::Middleware
          def on_complete(env)
            if env[:body].is_a?(Hash)
              env[:body] = camelcase(env[:body])
            end
          end

          private

          def camelcase(parsed_json)
            case parsed_json
            when Array
              parsed_json.map { |hash| lower_camel_stringify(hash) }
            when Hash
              lower_camel_stringify(parsed_json)
            end
          end

          def lower_camel_stringify(hash)
            hash.deep_transform_keys { |k| k.to_s.camelize(:lower) }
          end
        end
      end
    end
  end
end

Faraday::Request.register_middleware camelcase: Common::Client::Middleware::Request::Camelcase
