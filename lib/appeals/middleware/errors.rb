# frozen_string_literal: true

module Appeals
  module Middleware
    ##
    # Maps Faraday env status and add a source to the body hash.
    # This allows the raise_error middleware to correctly map the incoming error
    # to a [Common::Exceptions::BackendServiceException].
    #
    class Errors < Faraday::Response::Middleware
      ##
      # The response on complete callback. Adds code and source keys to the env body hash
      # if there's a non succesful response.
      #
      # @return [Hash, nil]
      #
      def on_complete(env)
        return if env.success?

        env[:body]['code'] = env.status
        env[:body]['source'] = 'Appeals Caseflow'
      end
    end
  end
end

Faraday::Response.register_middleware appeals_errors: Appeals::Middleware::Errors
