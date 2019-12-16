# frozen_string_literal: true

class StatsdMiddleware
  STATUS_KEY   = 'api.rack.request'
  DURATION_KEY = 'api.rack.request.duration'
  SOURCE_APP_NAMES = %w[
    0993-edu-benefits
    0994-edu-benefits
    1990-edu-benefits
    1990e-edu-benefits
    1990n-edu-benefits
    1995-STEM-edu-benefits
    1995-edu-benefits
    526EZ-all-claims
    526EZ-claims-increase
    5490-edu-benefits
    5495-edu-benefits
    686-dependent-status
    account
    auth
    beta-enrollment
    burials
    chapter31-vre
    chapter36-vre
    claims-status
    connected-accounts
    dashboard
    discharge-upgrade-instructions
    facilities
    feedback-tool
    gi
    hca
    id-card-beta
    letters
    my-health-account-validation
    pensions
    post-911-gib-status
    pre-need
    profile-360
    profile-360-beta
    proxy-rewrite
    public-outreach-materials
    search
    static-pages
    terms-and-conditions
    vaos
    verify
    veteran-id-card
    veteran-representative
    vic-v2
  ].freeze

  def initialize(app)
    @app = app
  end

  def call(env)
    start_time = Time.current
    status, headers, response = @app.call(env)
    duration = (Time.current - start_time) * 1000.0

    path_parameters = env['action_dispatch.request.path_parameters']

    # When ActionDispatch middleware is not processed, as is the case when middleware
    # such as Rack::Attack halts the call chain while applying a rate limit, path
    # parameters are not parsed. In this case, we don't have a controller or action
    # for the request.
    #
    # We should never use a dynamic path to apply the tag for the instrumentation,
    # since this will permit a rogue actor to increase the number of time series
    # exported from the process and causes instability in the metrics system. Effort
    # should be taken to track known conditions carefully in alternate metrics. For
    # the case of Rack::Attack rate limits, we can track the number of 429s responses
    # based on component at the reverse proxy layer, or with instrumentation provided
    # by the Rack::Attack middleware (which performs some rudimentary path matching)

    if path_parameters
      controller = path_parameters[:controller]
      action = path_parameters[:action]
      source_app = env['HTTP_SOURCE_APP_NAME']

      instrument_statsd(status, duration, controller, action, source_app)
    end

    [status, headers, response]
  end

  private

  def instrument_statsd(status, duration, controller, action, source_app)
    duration_tags = ["controller:#{controller}", "action:#{action}"]
    duration_tags.push("source_app:#{source_app}") if SOURCE_APP_NAMES.include?(source_app)

    status_tags = duration_tags + ["status:#{status}"]

    # rubocop:disable Style/RescueModifier
    StatsD.increment(STATUS_KEY, tags: status_tags) rescue nil
    StatsD.measure(DURATION_KEY, duration, tags: duration_tags) rescue nil
  end
end
