# frozen_string_literal: true

require 'committee'
require 'committee/unprocessable_entity_error'
require 'form21p530a/monitor'
require 'form214192/monitor'

schema_path = Rails.root.join('config', 'openapi', 'openapi.json').to_s

class CommitteeContext < ActiveSupport::CurrentAttributes
  attribute :controller, :action
end

module CommitteeErrorRouting
  # Mapping of path patterns to monitor classes
  FORM_MONITORS = {
    %r{^/v0/form21p530a} => Form21p530a::Monitor,
    %r{^/v0/form214192} => Form214192::Monitor
  }.freeze

  ##
  # Routes Committee validation errors to form-specific monitors based on request path
  #
  # @param request [Rack::Request] The incoming request
  # @return [Object, nil] The appropriate monitor instance or nil
  def self.monitor_for_request(request)
    FORM_MONITORS.find { |pattern, _| request.path.match?(pattern) }&.last&.new
  end

  ##
  # Populates path_parameters in env for StatsdMiddleware by matching against Rails routes
  # This ensures controller/action tags are present in metrics even when Committee validation fails
  #
  # @param env [Hash] The Rack environment hash
  def self.populate_path_parameters(env)
    return if env['action_dispatch.request.path_parameters'] # Already set by Rails

    # Extract path and method from env
    path = env['PATH_INFO']
    method = env['REQUEST_METHOD']&.downcase&.to_sym || :get

    # Use Rails router to recognize the path
    recognized = Rails.application.routes.recognize_path(path, method:)

    if recognized && recognized[:controller] && recognized[:action]
      env['action_dispatch.request.path_parameters'] = {
        controller: recognized[:controller],
        action: recognized[:action]
      }
    end
  rescue ActionController::RoutingError, StandardError => e
    # If route matching fails, log but don't raise
    Rails.logger.debug { "Failed to populate path_parameters for #{env['PATH_INFO']}: #{e.message}" }
  end

  ##
  # Logs Committee validation errors to Rails logger
  #
  # @param req [Rack::Request] The incoming request
  # @param ex [Committee::ValidationError] The validation error
  def self.log_rails_error(req, ex)
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

ERROR_HANDLER = lambda do |ex, env|
  req = Rack::Request.new(env)

  # Populate path_parameters so StatsdMiddleware can tag metrics with controller/action
  CommitteeErrorRouting.populate_path_parameters(env)
  path_params = env['action_dispatch.request.path_parameters'] || {}
  CommitteeContext.controller = path_params[:controller]
  CommitteeContext.action = path_params[:action]

  CommitteeErrorRouting.log_rails_error(req, ex)

  # Route to form-specific monitor if available
  monitor = CommitteeErrorRouting.monitor_for_request(req)
  if monitor && ex.is_a?(Committee::InvalidRequest)
    monitor.track_request_validation_error(error: ex, request: req)
  else
    # Fallback: metric only for paths without form-specific monitors
    error_type = ex.is_a?(Committee::InvalidRequest) ? 'request_validation' : 'response_validation'
    tags = [
      "error_type:#{error_type}",
      "path:#{req.path}",
      "source_app:#{req.env['SOURCE_APP'] || 'unknown'}"
    ]
    StatsD.increment('api.committee.validation_error', tags:)
  end
end

Rails.application.config.middleware.use(
  Committee::Middleware::RequestValidation,
  schema_path:,
  strict_reference_validation: true,
  raise: false,
  error_class: Committee::UnprocessableEntityError,
  error_handler: ERROR_HANDLER
)

Rails.application.config.middleware.use(
  Committee::Middleware::ResponseValidation,
  schema_path:,
  strict_reference_validation: true,
  validate_success_only: true,
  raise: false,
  error_class: Committee::UnprocessableEntityError,
  error_handler: ERROR_HANDLER
)
