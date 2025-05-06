# frozen_string_literal: true

module SimpleFormsApi
  module FormRemediation
    class Error < StandardError
      attr_reader :base_error, :details

      DEFAULT_MESSAGE = 'An error occurred during the form remediation process'

      def initialize(message: DEFAULT_MESSAGE, error: nil, details: nil, backtrace: nil)
        super(message)
        @base_error = error
        @details = details
        @custom_backtrace = backtrace
      end

      def message
        [super, custom_message].compact.join(' - ')
      end

      def backtrace
        @custom_backtrace || base_error&.backtrace || super
      end

      private

      def custom_message
        details.is_a?(Hash) ? details[:message] : base_error&.message
      end

      private_constant :DEFAULT_MESSAGE
    end
  end
end
