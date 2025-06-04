# frozen_string_literal: true

module PDFUtilities
  module ExceptionHandling

    class PdfMissingError < StandardError; end
    class StampGenerationError < StandardError; end
    class PdfStampingError < StandardError; end

    def log_and_raise_error(message, e)
      combined_message = "#{message}: #{e.message}"
      monitor.track(:error, combined_message, 'api.pdf_stamper.error', exception: e.message, backtrace: e.backtrace)

      raise e.class, combined_message, e.backtrace
    end

    def monitor
      @monitor ||= Logging::Monitor.new('pdf_utilities')
    end
  end
end
