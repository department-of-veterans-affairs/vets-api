# frozen_string_literal: true

module Common
  module Exceptions
    # Forbidden is excluded from Sentry logging. This exception is a duplicate
    # that IS NOT excluded from Sentry logging
    class UnexpectedForbidden < Forbidden
      def i18n_key
        "common.exceptions.#{self.class.superclass.name.split('::').last.underscore}"
      end
    end
  end
end
