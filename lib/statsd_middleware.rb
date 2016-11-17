# frozen_string_literal: true
class StatsdMiddleware
  def initialize(app)
    @app = app
  end

  def call(env)
    start_time = Time.current
    status, headers, response = @app.call(env)
    duration = Time.current - start_time

    controller = env['action_dispatch.request.path_parameters'][:controller]
    action = env['action_dispatch.request.path_parameters'][:action]
    status_key = "api.external.request#status=#{status},controller=#{controller},action=#{action}"
    duration_key = "api.external.request.duration#controller=#{controller},action=#{action}"

    # rubocop:disable Lint/HandleExceptions
    begin
      StatsD.increment(status_key, 1)
      StatsD.measure(duration_key, duration)
    rescue
      # we want to ensure this doesn't break the response cyce
    end
    # rubocop:enable Lint/HandleExceptions
    [status, headers, response]
  end
end
