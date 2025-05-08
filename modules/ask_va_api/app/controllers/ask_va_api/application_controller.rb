# frozen_string_literal: true

module AskVAApi
  class ApplicationController < ::ApplicationController
    service_tag 'ask-va'

    around_action :handle_exceptions
    # The before_action is global and applied to all actions in the controller,
    before_action :check_maintenance_mode_in_prod

    private

    def check_maintenance_mode_in_prod
      if Flipper.enabled?(:ask_va_api_maintenance_mode) && Settings.vsp_environment == 'production'
        render json: {
                 error: 'The Ask VA service is temporarily unavailable due to scheduled maintenance. ' \
                        'Please try again later.'
               },
               status: :service_unavailable
      end
    end

    def handle_exceptions
      yield
    rescue Common::Exceptions::Unauthorized => e
      log_and_render_error('unauthorized', e, :unauthorized)
    rescue ErrorHandler::ServiceError,
           Crm::ErrorHandler::ServiceError,
           Common::Exceptions::ValidationErrors,
           Inquiries::InquiriesCreatorError => e

      status = e.message.include?('No Inquiries found') ? :not_found : :unprocessable_entity
      log_and_render_error('service_error', e, status)
    rescue => e
      log_and_render_error('unexpected_error', e, :internal_server_error)
    end

    def log_and_render_error(action, exception, status)
      log_error(action, exception)
      render json: exception.respond_to?(:to_h) ? exception.to_h : { error: exception.message }, status:
    end

    def log_error(action, exception)
      safe_fields = exception.try(:context).try(:[], :safe_fields)

      LogService.new.call(action) do |span|
        span.set_tag('error', true)
        span.set_tag('error.msg', exception.message)
        span.set_tag('safe_field.idme_uuid', current_user&.idme_uuid)
        span.set_tag('safe_field.logingov_uuid', current_user&.logingov_uuid)
        span.set_error(exception)

        if safe_fields.present?
          safe_fields.each do |key, value|
            span.set_tag("safe_field.#{key}", value.to_s)
          end
        end
      end

      Rails.logger.error("Error during #{action}: #{exception.message}")
    end
  end
end
