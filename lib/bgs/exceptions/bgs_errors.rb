# frozen_string_literal: true

require 'bgs/exceptions/service_exception'
module BGS
  module Exceptions
    module BGSErrors
      include SentryLogging
      MAX_ATTEMPTS = 3

      def with_multiple_attempts_enabled
        attempt ||= 0
        yield
      rescue => e
        attempt += 1
        if attempt < MAX_ATTEMPTS
          notify_of_service_exception(e, __method__.to_s, attempt, :warn)
          retry
        end

        notify_of_service_exception(e, __method__.to_s)
      end

      def notify_of_service_exception(error, method, attempt = nil, status = :error)
        msg = "Unable to #{method}: #{error.message}: try #{attempt} of #{MAX_ATTEMPTS}"
        context = { icn: @user[:icn] }
        tags = { team: 'vfs-ebenefits' }

        return log_message_to_sentry(msg, :warn, context, tags) if status == :warn

        log_exception_to_sentry(error, context, tags)
        raise_backend_exception('BGS_686c_SERVICE_403', self.class, error)
      end

      def raise_backend_exception(key, source, error)
        exception = BGS::ServiceException.new(
          key,
          { source: source.to_s },
          403,
          error.message
        )

        raise exception
      end
    end
  end
end
