# frozen_string_literal: true

module AskVAApi
  class ApplicationController < ::ApplicationController
    service_tag 'ask-va'

    private

    def handle_exceptions
      yield
    rescue ErrorHandler::ServiceError, Crm::ErrorHandler::ServiceError => e
      log_and_render_error('service_error', e, :unprocessable_entity)
    rescue => e
      log_and_render_error('unexpected_error', e, :internal_server_error)
    end

    def log_and_render_error(action, exception, status)
      log_error(action, exception)
      render json: { error: exception.message }, status:
    end

    def log_error(action, exception)
      LogService.new.call(action) do |span|
        span.set_tag('error', true)
        span.set_tag('error.msg', exception.message)
      end
      Rails.logger.error("Error during #{action}: #{exception.message}")
    end
  end
end
