# frozen_string_literal: true

module Appeals
  module Middleware
    class Errors < Faraday::Response::Middleware
      def on_complete(env)
        return if env.success?
        env[:body]['code'] = env.status
        env[:body]['source'] = 'Appeals Caseflow'
      end
    end
  end
end

Faraday::Response.register_middleware appeals_errors: Appeals::Middleware::Errors
