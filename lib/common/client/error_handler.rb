# frozen_string_literal: true

module Common
  module Client
    ##
    # This class is responsible for providing a public interface with which to perform common error handling tasks.
    class ErrorHandler
      extend SentryLogging
      attr_accessor :error, :meta

      def self.handle(error)
        log_error(error)
      end
    end
  end
end
