# frozen_string_literal: true

module Middleware
  class Errors < Faraday::Response::Middleware
    def on_complete(env)
      return if env.success?

      Raven.extra_context(message: env.body, url: env.url)

      case env.status
      when 400, 409
        error_400(env.body)
      when 403
        raise Common::Exceptions::BackendServiceException.new('CHECK_IN_403', source: self.class)
      when 404
        raise Common::Exceptions::BackendServiceException.new('CHECK_IN_404', source: self.class)
      when 500..510
        raise Common::Exceptions::BackendServiceException.new('CHECK_IN_502', source: self.class)
      else
        raise Common::Exceptions::BackendServiceException.new('VA900', source: self.class)
      end
    end

    def error_400(body)
      raise Common::Exceptions::BackendServiceException.new(
        'CHECK_IN_400',
        title: 'Bad Request',
        detail: parse_error(body),
        source: self.class
      )
    end

    def parse_error(body)
      parsed ||= Oj.load(body)

      if parsed['errors']
        parsed['errors'].first['errorMessage']
      else
        parsed['message']
      end
    rescue
      body
    end
  end
end
