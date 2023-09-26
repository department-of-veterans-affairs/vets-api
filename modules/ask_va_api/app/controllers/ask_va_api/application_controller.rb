# frozen_string_literal: true

module AskVAApi
  class ApplicationController < ::ApplicationController
    private

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
