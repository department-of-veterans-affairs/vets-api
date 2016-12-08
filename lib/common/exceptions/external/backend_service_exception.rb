# frozen_string_literal: true
module Common
  module Exceptions

    class UnmappedBackendServiceException < StandardError
    # BackendServiceException - This will return a generic error, to customize
    # you must define the minor code in the locales file and call this class from
    # raise_error middleware.
    class BackendServiceException < BaseError
      attr_reader :response_values

      def initialize(key = nil, response_values = {})
        @response_values = response_values
        @key = key || 'VA900'
        validate_arguments!
        warn_about_error_not_in_locales!
      end

      def message
        "BackendServiceException: #{response_values}"
      end

      def errors
        Array(SerializableError.new(i18n_data.merge(render_overides)))
      end

      private

      def render_overides
        { code: code, detail: detail, status: status, source: source }
      end

      def validate_arguments!
        raise ArgumentError, "i18n key (#{@key}) is invalid" unless I18n.exists?(i18n_key)
        raise ArgumentError, "status (#{status}) is not in 4xx range" unless status.between?(400, 499)
      end

      # This just reports to Sentry that an unmapped backend service exception was
      # identified it does not actually raise an exception.
      # NOTE: in the future detail will just fallback to 'Operation failed'
      def warn_about_error_not_in_locales!
        unless i18n_data[:detail].present?
          message = <<-MESSAGE.strip_heredoc
            Referencing detail from response values is deprecated. Add the following to exceptions.en.yml
            #{response_values[:code]}:
              code: '#{response_values[:code]}'
              detail: '#{response_values[:detail]}'
              status: <http status code you want rendered (400 or 422)>
              source: #{response_values[:source].presence || '~'}
          MESSAGE
          exception = UnmappedBackendServiceException.new(message)
          Rails.logger.warn message
          Raven.capture_exception(exception) if ENV['SENTRY_DSN'].present?
        end
      end

      # This is the code returned from raise_error middleware. If it exists in
      # I18n then it should be like RX139 or EVSS144, otherwise VA900
      def code
        i18n_key
      end

      # The http status code. This is required for rendering!
      # unless you've specified that you want the status code to be something other
      # then 400 explicitly it will default to 400. IT WILL NOT DEFAULT to whatever
      # was provided by the backend service, because the backend service response
      # might not always be relevant
      def status
        i18n_data[:source].presence || 400
      end

      # Default detail should be based on i18n
      # this overrides the value from response so that one can customize the value
      # NOTE: a value of a nil will render the detail as title when serializing errors
      def detail
        i18n_data[:detail].presence || response_values[:detail]
      end

      # This should usually be a developer message of some sort from the backend service
      def source
        response_values[:source]
      end

      def i18n_key
        "common.exceptions.#{@key}"
      end
    end
  end
end
