module Common
  module Client
    module Middleware
      module Response
        class JsonParser < Faraday::Response::Middleware
          WHITESPACE_REGEX = /\A^\s*$\z/
          MHV_SUCCESS_REGEX = /^success/i
          UNPARSABLE_STATUS_CODES = [204, 301, 302, 304]

          def on_complete(env)
            return unless env.response_headers['content-type'] =~ /\bjson/
            if respond_to?(:parse)
              env[:body] = parse_body(env[:body]) unless UNPARSABLE_STATUS_CODES.include?(env[:status])
            end
          end

          private

          def parse_body(body = nil)
            case body
            when WHITESPACE_REGEX, nil
              nil
            when MHV_SUCCESS_REGEX
              nil
            else
              json = begin
                MultiJson.load(body)
              rescue MultiJson::LoadError => error
                raise Common::Client::Errors::Serialization, error
              end
            end
          end
        end
      end
    end
  end
end

Faraday::Response.register_middleware json_parser: Common::Client::Middleware::Response::JsonParser
