# frozen_string_literal: true

module Common
  module Client
    module Middleware
      class Logging < Faraday::Middleware
        def initialize(app, type_key)
          super(app)
          @type_key = type_key
        end

        def call(env)
          request_body = Base64.encode64(env.body) if env.body

          @app.call(env).on_complete do |response_env|
            PersonalInformationLog.create(
              error_class: @type_key, # TODO: error_class is probably worth renaming
              data: {
                method: env.method,
                url: env.url.to_s,
                request_body: request_body,
                response_body: Base64.encode64(handle_response_bodies(response_env.body))
              }
            )
          end
        end

        private

        # consider adding additional handling for JSON document bodies in the future
        def handle_response_bodies(body)
          if body.is_a?(Ox::Document)
            Ox.dump(body)
          else
            body
          end
        end
      end
    end
  end
end

Faraday::Middleware.register_middleware logging: Common::Client::Middleware::Logging
