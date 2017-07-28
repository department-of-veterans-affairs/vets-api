# frozen_string_literal: true
require 'sentry_logging'
module Common
  module Exceptions
    # This will return a generic error, to customize
    # you must define the minor code in the locales file and call this class from
    # raise_error middleware.
    class BackendServiceException < BaseError
      attr_reader :service_response

      def initialize(key = nil, service_response = {})
        @key = key || 'VA900'
        @service_response = service_response
        validate_arguments!
      end

      def trigger_breakers?
        (500..599).cover?(original_status || status)
      end

      # The message will be the actual backend service response from middleware,
      # not the I18n version.
      def message
        "BackendServiceException: #{code} - #{detail || service_response[:detail]}"
      end

      def errors
        Array(SerializableError.new(i18n_data.merge(render_overides)))
      end

      # VA900 is characterized as a generic type of exception. See exceptions.en.yml for what JSON will render
      def va900?
        code == 'VA900'
      end

      alias generic_error? va900?

      def va900_warning
        "Unmapped VA900 (Backend Response: { status: #{original_status}, message: #{original_body}) }"
      end

      def va900_hint
        <<-MESSAGE.strip_heredoc
          Add the following to exceptions.en.yml
          #{service_response[:code]}:
            code: '#{service_response[:code]}'
            detail: '#{service_response[:detail]}'
            status: <http status code you want rendered (400, 422, etc)>
            source: ~
        MESSAGE
      end

      def original_body
        service_response[:body] || service_response[:original_body]
      end

      def original_status
        service_response[:status] || service_response[:original_status]
      end

      def original_header
        service_response[:header] || service_response[:original_header]
      end

      private

      def render_overides
        { status: status, detail: detail, code: code, source: source }
      end

      # REQUIRED - This is the i18n code returned from raise_error middleware. If it exists in
      # I18n then it should be like RX139 or EVSS144, otherwise VA900
      def code
        if @key.present? && I18n.exists?("common.exceptions.#{@key}")
          @key
        else
          'VA900'
        end
      end

      # REQUIRED - This is the http status code.
      def status
        i18n_data[:status] || 400
      end

      # OPTIONAL - This is the detail or message that is rendered in JSON response
      # Not providing detail will render a detail the same as title, 'Operation failed'
      def detail
        i18n_data[:detail] || service_response[:detail]
      end

      # OPTIONAL - This should usually be a developer message of some sort from the backend service
      # if one is not provided by the backend this can be nil and the key will not be rendered
      def source
        service_response[:source]
      end

      def validate_arguments!
        raise ArgumentError, "i18n key (#{@key}) is invalid" unless I18n.exists?(i18n_key)
        raise ArgumentError, "status (#{status}) is not in range" unless status.between?(400, 599)
      end

      def i18n_key
        "common.exceptions.#{code}"
      end
    end
  end
end
