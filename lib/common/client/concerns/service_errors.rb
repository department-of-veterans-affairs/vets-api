# frozen_string_literal: true

module Common::Client
  module ServiceErrors
    extend ActiveSupport::Concern

    def handle_service_error(error)
      log_original_error(error)
      handle_error(error)
    end

    private

    def handle_error(error)
      case error.status
      when 401
        raise Common::Exceptions::BadGateway, error_details(
          "Received an unauthorized (401) response from the upstream server, check this error's source for event id"
        )
      when 403
        raise Common::Exceptions::Forbidden, error_details('The upstream server responded 403 Forbidden')
      when 404
        raise Common::Exceptions::ResourceNotFound, error_details(
          'The upstream server responded 404 Resource not found'
        )
      when 422
        raise Common::Exceptions::UnprocessableEntity, error_details(
          'The upstream server responded 422 Unprocessable entity (validation error)'
        )
      else
        raise Common::Exceptions::BadGateway, error_details(
          "The app received an invalid response from the upstream server, check this error's source for event id"
        )
      end
    end

    def log_original_error(error)
      level, message = if (401...500).cover? error.status
                         [:info, "#{self.class} handled an expected #{error.message}"]
                       else
                         [:error, "#{self.class} handled an unexpected #{error.message}"]
                       end
      log_message_to_sentry(message, level, extra_context: { url: config.base_path, body: error.body })
      @last_event_id = Raven.last_event_id
    end

    def error_details(message)
      {
        detail: message,
        source: { class: self.class, event_id: @last_event_id }
      }
    end
  end
end
