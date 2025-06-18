# frozen_string_literal: true

# require 'common/exceptions/service_error'

module Common
  module Exceptions
    class InvalidPOA < BaseError
      def initialize(claimant_icn = nil)
        claimant_icn
      end

      def errors
        Array(SerializableError.new(i18n_interpolated(detail: { claimant_icn: @claimant_icn })))
      end
    end
  end
end
