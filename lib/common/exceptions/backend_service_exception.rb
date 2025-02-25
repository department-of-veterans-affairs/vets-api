# frozen_string_literal: true

require 'sentry_logging'
require 'common/exceptions/base_error'

module Common
  module Exceptions
    # This will return a generic error, to customize
    # you must define the minor code in the locales file and call this class from
    # raise_error middleware.
    class BackendServiceException < BaseError
      attr_reader :response_values, :original_status, :original_body, :key

      # rubocop:disable Metrics/ParameterLists
      def initialize(key = nil, response_values = {}, original_status = nil, original_body = nil)
        @response_values = response_values
        @key = key || 'VA900'
        @original_status = original_status
        @original_body = original_body
        validate_arguments!
      end
      # rubocop:enable Metrics/ParameterLists

      # The message will be the actual backend service response from middleware,
      # not the I18n version.
      def message
        "BackendServiceException: #{response_values.merge(code:)}"
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
        <<~MESSAGE
          Add the following to exceptions.en.yml
          #{response_values[:code]}:
            code: '#{response_values[:code]}'
            detail: '#{response_values[:detail]}'
            status: <http status code you want rendered (400, 422, etc)>
            source: ~
        MESSAGE
      end

      private

      def render_overides
        { status:, detail:, code:, source: }
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
      # unless you've specified that you want the status code to be something other
      # then 400 explicitly it will default to 400. IT WILL NOT DEFAULT to whatever
      # was provided by the backend service, because the backend service response
      # might not always be relevant
      def status
        i18n_data[:status].presence || 400
      end

      # OPTIONAL - This is the detail or message that is rendered in JSON response
      # Not providing detail will render a detail the same as title, 'Operation failed'
      # NOTE: in the future, detail will only work via i18n, not the value from response_values
      def detail
        i18n_data[:detail].presence || response_values[:detail]
      end

      # OPTIONAL - This should usually be a developer message of some sort from the backend service
      # if one is not provided by the backend this can be nil and the key will not be rendered
      def source
        response_values[:source]
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
