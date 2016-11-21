# frozen_string_literal: true
class StatsdMiddleware
  STATUS_KEY   = 'api.rack.request'
  DURATION_KEY = 'api.rack.request.duration'

  def initialize(app)
    @app = app
  end

  def call(env)
    start_time = Time.current
    status, headers, response = @app.call(env)
    duration = (Time.current - start_time) * 1000.0

    controller = env['action_dispatch.request.path_parameters'][:controller]
    action = env['action_dispatch.request.path_parameters'][:action]

    duration_tags = ["controller:#{controller}", "action:#{action}"]
    status_tags = duration_tags + ["status:#{status}"]

    # rubocop:disable Style/RescueModifier
    StatsD.increment(STATUS_KEY, tags: status_tags) rescue nil
    StatsD.measure(DURATION_KEY, duration, tags: duration_tags) rescue nil
    # rubocop:enable Style/RescueModifier
    [status, headers, response]
  end
end
