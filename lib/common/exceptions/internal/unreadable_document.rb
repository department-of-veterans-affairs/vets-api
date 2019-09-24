module Common
  module Exceptions
    class UnreadableDocument < BaseError
      attr_reader :document

      def initialize(document)
        @document = document
      end

      def errors
        Array(SerializableError.new(i18n_interpolated(detail: { document: @document })))
      end
    end
  end
end
