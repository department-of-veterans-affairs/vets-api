# frozen_string_literal: true

require 'common/exceptions/base_error'
require 'common/exceptions/serializable_error'

module VAOS
  module Exceptions
    class ValidationErrors < Common::Exceptions::BaseError
      def initialize(result)
        @result = result
        super
      end

      def errors
        @result.errors(full: true).messages.map do |message|
          Common::Exceptions::SerializableError.new(detail: message)
        end
      end
    end
  end
end
