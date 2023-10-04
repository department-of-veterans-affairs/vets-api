# frozen_string_literal: true

module AskVAApi
  class ApplicationController < ::ApplicationController
    private

    def handle_exceptions
      yield
    rescue AskVAApi::V0::InquiriesController::InvalidInquiryError => e
      log_and_render_error('invalid_inquiry_error', e, :bad_request)
    rescue ErrorHandler::ServiceError, Dynamics::ErrorHandler::ServiceError => e
      log_and_render_error('service_error', e, :unprocessable_entity)
    rescue => e
      log_and_render_error('unexpected_error', e, :internal_server_error)
    end

    def log_and_render_error(action, exception, status)
      log_error(action, exception)
      render json: { error: exception.message }, status:
    end

    def log_error(action, exception)
      DatadogLogger.new.call(action) do |span|
        span.set_tag('error', true)
        span.set_tag('error.msg', exception.message)
      end
      Rails.logger.error("Error during #{action}: #{exception.message}")
    end

    def service_exception_handler(ex)
      context = 'An error occurred while attempting to retrieve the authenticated list of devs.'
      log_exception_to_sentry(ex, 'context' => context)
      raise exception unless ex.status == '401' || ex.status == '403'
    end
  end
end
