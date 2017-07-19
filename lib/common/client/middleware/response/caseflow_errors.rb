# frozen_string_literal: true
module Common
  module Client
    module Middleware
      module Response
        class CaseflowErrors < Faraday::Response::Middleware
          def on_complete(env)
            return if env.success?
            mappedError = env[:body]['errors']&.first
            return if mappedError.nil?
            # Caseflow does not generally populate a "code" so we 
            # fall back to using the status as a code. 
            env[:body]['code'] = mappedError['code'] || mappedError['status']
            env[:body]['detail'] = mappedError['title']
            env[:body]['source'] = mappedError['detail']
          end
        end
      end
    end
  end
end

Faraday::Response.register_middleware caseflow_errors: Common::Client::Middleware::Response::CaseflowErrors
