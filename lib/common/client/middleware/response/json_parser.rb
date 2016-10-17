module Common
  module Client
    module Middleware
      module Response
        class JsonParser < Faraday::Response::Middleware
          WHITESPACE_REGEX = /\A^\s*$\z/
          MHV_SUCCESS_REGEX = /^success/i
          UNPARSABLE_STATUS_CODES = [204, 301, 302, 304]

          def on_complete(env)
            if env.response_headers['content-type'] =~ /\bjson/
              if env.body =~ WHITESPACE_REGEX || env.body =~ MHV_SUCCESS_REGEX
                env.body = {}
              else
                env.body = parse(env.body) unless UNPARSABLE_STATUS_CODES.include?(env[:status])
              end
            end
          end

          def parse(body = nil)
            json = begin
              MultiJson.load(body)
            rescue MultiJson::LoadError => error
              raise Common::Client::Errors::Serialization, error
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

Faraday::Response.register_middleware json_parser: Common::Client::Middleware::Response::JsonParser
