require 'committee'
require_relative 'unprocessable_entity_error'

module Committee
  class Config
    ERROR_HANDLER = lambda do |ex, env|
      req = Rack::Request.new(env)
      Rails.logger.warn(
        '[Committee] Request validation failed',
        {
          path: req.path,
          method: req.request_method,
          status: 422,
          error_class: ex.class.name.demodulize,
          error_type: ex.is_a?(Committee::InvalidRequest) ? 'request_validation' : 'response_validation'
        }
      )
    end
  end
end
