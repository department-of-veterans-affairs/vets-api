# frozen_string_literal: true

# Render 405 response for ActionController::UnknownHttpMethod exceptions like:
# (ActionController::UnknownHttpMethod) "CONNECT, accepted HTTP methods are get, head, put, post, delete, and options"
# (ActionController::UnknownHttpMethod) "PROPFIND, accepted HTTP methods are get, head, put, post, delete, and options"
class HttpMethodNotAllowed
  def initialize(app)
    @app = app
  end

  def call(env)
    if !ActionDispatch::Request::HTTP_METHODS.include?(env['REQUEST_METHOD'].upcase)
      Rails.logger.info("ActionController::UnknownHttpMethod: #{env['REQUEST_METHOD']}")
      [405, { 'Content-Type' => 'text/plain' }, ['Method Not Allowed']]
    else
      @status, @headers, @response = @app.call(env)
      [@status, @headers, @response]
    end
  end
end
