# frozen_string_literal: true

module Common
  # This class provides a public interface that can be used to perform common error handling tasks.
  class ErrorHandler
    extend SentryLogging
    attr_accessor :error, :meta

    def self.handle(error)
      log_error(error)
    end
  end
end
