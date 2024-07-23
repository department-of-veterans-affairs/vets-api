# frozen_string_literal: true

module Common
  module Client
    module Middleware
      module Response
        class Snakecase < Faraday::Middleware
          def initialize(app, options = { symbolize: true })
            super(app)
            @symbolize = options[:symbolize]
          end

          def on_complete(env)
            # return false unless env.response_headers['content-type'] =~ /\b(xml|json)/
            return unless deserialized_body?(env.body)

            env.body = parse(env.body)
          end

          def parse(parsed_object)
            case parsed_object
            when Array
              parsed_object.map { |hash| transform(hash) }
            when Hash
              transform(parsed_object)
            end
          end

          private

          def deserialized_body?(body)
            body.is_a?(Array) || body.is_a?(Hash)
          end

          def transform(hash)
            if @symbolize
              hash.deep_transform_keys { |k| k.underscore.to_sym }
            else
              hash.deep_transform_keys(&:underscore)
            end
          end
        end
      end
    end
  end
end

Faraday::Response.register_middleware snakecase: Common::Client::Middleware::Response::Snakecase
