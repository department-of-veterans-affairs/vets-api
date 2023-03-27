# frozen_string_literal: true

module Sentry
  module Processor
    class EmailSanitizer < Raven::Processor
      # source: https://stackoverflow.com/a/27194235
      EMAIL_REGEX = /\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b/i

      # largely duplicated code from from the raven-ruby lib as recommended in their doc
      # https://github.com/getsentry/raven-ruby/blob/master/lib/raven/processor/utf8conversion.rb#L9
      def process(value)
        case value
        when Hash
          value.frozen? ? value.merge(value) { |_, v| process v } : value.merge!(value) { |_, v| process v }
        when Array
          value.frozen? ? value.map { |v| process v } : value.map! { |v| process v }
        when Exception
          sanitized_exception(value)
        when String
          sanitized_string(value)
        else
          value
        end
      end

      private

      def sanitized_string(str)
        str.gsub(EMAIL_REGEX, '[FILTERED EMAIL]')
      end

      def sanitized_exception(exception)
        return exception unless contains_email?(exception.message)

        clean_exc = exception.class.new(sanitized_string(exception.message))
        clean_exc.set_backtrace(exception.backtrace)
        clean_exc
      end

      def contains_email?(str)
        EMAIL_REGEX.match(str)
      end
    end
  end
end
