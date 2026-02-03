# frozen_string_literal: true

require 'bgs/exceptions/service_exception'
require 'bgs/monitor'

module BGS
  module Exceptions
    module BGSErrors
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
        # CEST11 errors include PII. Override message to avoid logging sensitive information.
        if error.message.present? && error.message.include?('CEST11')
          raise_backend_exception('BGS_686c_SERVICE_403', self.class, error.class.new('CEST11 Error'))
        end

        msg = "Unable to #{method}: #{error.message}: try #{attempt} of #{MAX_ATTEMPTS}"
        return monitor.warn(msg, 'service_exception_warning') if status == :warn

        if oracle_error?(error:)
          log_oracle_errors!(error:)
        else
          monitor.error(error.message, 'service_exception')
        end
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

      private

      # BGS sometimes returns errors containing an enormous stacktrace with an oracle error. This method logs the oracle
      # error message and excludes everything else. These oracle errors start with the signature `ORA-` and are
      # bookended by a `prepstmnt` clause. See `spec/fixtures/bgs/bgs_oracle_error.txt` for an example. We want to log
      # these errors separately because the original error message is so long that it obscures its only relevant
      # information and actually breaks Sentry's UI.
      def log_oracle_errors!(error:)
        match_data = oracle_error_match_data(error:)
        monitor.error(match_data[0], 'oracle_error') if match_data
      end

      # Checks if an error contains an Oracle database error signature.
      #
      # @param error [Exception] The error to check for Oracle error patterns
      # @return [Boolean] true if the error contains Oracle error patterns
      def oracle_error?(error:)
        oracle_error_match_data(error:)&.length&.positive?
      end

      # Extracts Oracle error message using regex pattern matching.
      #
      # @param error [Exception] The error containing potential Oracle error message
      # @return [MatchData, nil] MatchData object if Oracle error found, nil otherwise
      def oracle_error_match_data(error:)
        error.message.match(/ORA-.+?(?=\s*{prepstmnt)/m)
      end

      def monitor
        @monitor ||= BGS::Monitor.new
      end
    end
  end
end
