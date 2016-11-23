# frozen_string_literal: true
module Common
  module Exceptions
    # ClientError - Generic Backend errors returned from api calls
    class ClientError < BaseError
      def initialize(error_klass = nil, options = {})
        @error_klass = error_klass || 'client_error'
        @detail = options[:detail]
        @source = options[:source]
        @meta = options[:meta] unless Rails.env.production?
      end

      def errors
        Array(SerializableError.new(i18n_data.merge(detail: @detail, source: @source, meta: @meta)))
      end

      private

      def i18n_key
        "common.exceptions.#{@error_klass}"
      end
    end
  end
end
