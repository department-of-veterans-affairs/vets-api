# frozen_string_literal: true
class StatsdMiddleware
  def initialize(app)
    @app = app
  end

  def call(env)
    status, headers, response = @app.call(env)
    params = env['action_dispatch.request.path_parameters']
    key = "api.external.request#status=#{status},controller=#{params[:controller]},action=#{params[:action]}"
    # rubocop:disable Lint/HandleExceptions
    begin
      StatsD.increment(key, 1)
    rescue
      # we want to ensure this doesn't break the response cyce
    end
    # rubocop:enable Lint/HandleExceptions
    [status, headers, response]
  end
end
