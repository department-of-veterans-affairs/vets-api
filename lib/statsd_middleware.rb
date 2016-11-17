# frozen_string_literal: true
class StatsdMiddleware
  def initialize(app)
    @app = app
  end

  def call(env)
    status, headers, response = @app.call(env)
    params = env['action_dispatch.request.path_parameters']
    key = "api.external.request#status=#{status},controller=#{params[:controller]},action=#{params[:action]}"
    StatsD.increment(key, 1)
    [status, headers, response]
  end
end
