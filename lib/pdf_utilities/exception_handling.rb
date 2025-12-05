# frozen_string_literal: true

require 'logging/monitor'

# Utility classes and functions for VA PDF
module PDFUtilities
  # include for handling exceptions in pdf functions
  module ExceptionHandling
    # pdf is missing
    class PdfMissingError < StandardError; end
    # error during generation
    class StampGenerationError < StandardError; end
    # error during stamping
    class PdfStampingError < StandardError; end

    # log an error, track stats, and re-raise the error with the combined message
    #
    # @param message [String] custom message; will be combined with error message
    # @param e [Error] the error
    # @param stats_key [String] the statsd tracking metric
    #
    # @raise [Error] same error class as `e` with combined message and same backtrace
    def log_and_raise_error(message, e, stats_key)
      combined_message = "#{message}: #{e.message}"
      monitor.track_request(:error, combined_message, stats_key, exception: e.message, backtrace: e.backtrace)

      raise e.class, combined_message, e.backtrace
    end

    # the pdf utilities monitor
    # @see Logging::Monitor
    def monitor
      allowlist = %w[exception backtrace]
      @monitor ||= Logging::Monitor.new('pdf_utilities', allowlist:)
    end
  end
end
