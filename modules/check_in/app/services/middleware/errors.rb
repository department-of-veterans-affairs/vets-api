# frozen_string_literal: true

module Middleware
  class Errors < Faraday::Response::Middleware
    ##
    # Faraday middleware method that runs when the response is finished
    #
    # @param env [Object]
    # @return [Common::Exceptions::BackendServiceException]
    #
    def on_complete(env)
      return if env.success?

      Raven.extra_context(message: env.body, url: env.url)

      case env.status
      when 400
        raise_exception('CHECK_IN_400')
      when 403
        raise_exception('CHECK_IN_403')
      when 404
        raise_exception('CHECK_IN_404')
      when 500..510
        raise_exception('CHECK_IN_502')
      else
        raise_exception('VA900')
      end
    end

    ##
    # Helper method for the `on_complete` method
    #
    # @param title [String]
    # @return [Common::Exceptions::BackendServiceException]
    #
    def raise_exception(title)
      raise Common::Exceptions::BackendServiceException.new(title, source: self.class)
    end
  end
end
