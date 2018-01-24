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
        raise Common::Exceptions::Unauthorized.new(error_details('The upstream server responded 401 Unauthorized'))
      when 403
        raise Common::Exceptions::Forbidden.new(error_details('The upstream server responded 403 Forbidden'))
      when 404
        raise Common::Exceptions::ResourceNotFound.new(
          error_details('The upstream server responded 404 Resource not found')
        )
      when 422
        raise Common::Exceptions::UnprocessableEntity.new(
          error_details('The upstream server responded 422 Unprocessable entity (validation error)')
        )
      else
        raise Common::Exceptions::BadGateway.new(
          error_details(
            "The app received an invalid response from the upstream server, check this error's source for event id"
          )
        )
      end
    end

    def log_original_error(error)
      level, message = if error.status === (400...500)
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
