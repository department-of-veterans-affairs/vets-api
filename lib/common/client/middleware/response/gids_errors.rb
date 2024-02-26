# frozen_string_literal: true

module Common
  module Client
    module Middleware
      module Response
        class GIDSErrors < Faraday::Middleware
          # TODO: Consider consolidating this with caseflow_errors middleware
          # into a common json_api_errors middleware
          def on_complete(env)
            return if env.success?

            mapped_error = env[:body]['errors']&.first
            return if mapped_error.nil?

            # GIDS does not generally populate a "code" so we
            # fall back to using the status as a code.
            env[:body]['code'] = mapped_error['code'] || mapped_error['status']
            env[:body]['detail'] = mapped_error['title']
            env[:body]['source'] = mapped_error['detail']
          end
        end
      end
    end
  end
end

Faraday::Response.register_middleware gids_errors: Common::Client::Middleware::Response::GIDSErrors
