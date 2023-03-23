# frozen_string_literal: true

require 'common/exceptions/base_error'
require 'common/exceptions/serializable_error'

module Common
  module Exceptions
    # Record Not Found - if no record exists having id, or resource having id does not belong to requester
    class RecordNotFound < BaseError
      attr_reader :id

      def initialize(id, detail: nil)
        @id = id
        @detail = detail
      end

      def errors
        detail = @detail.presence || { id: @id }
        Array(SerializableError.new(i18n_interpolated(detail:)))
      end
    end
  end
end
