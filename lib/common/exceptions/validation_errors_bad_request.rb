# frozen_string_literal: true

require 'common/exceptions/validation_errors'

module Common
  module Exceptions
    class ValidationErrorsBadRequest < ValidationErrors
      def status_code
        400
      end

      private

      def error_attributes(key, message, _full_message)
        i18n_data.merge(
          title: "invalid value for #{key}",
          detail: "#{message} is not valid for #{key}",
          source: { pointer: key.to_s }
        )
      end
    end
  end
end
