# frozen_string_literal: true
module Common
  module Exceptions
    # Base error class all others inherit from
    # TODO: possibly fine tune inheritance with additional BaseError classes
    class BaseError < StandardError
      def errors
        raise NotImplementedError, 'Subclass of Error must implement errors method'
      end
    end
  end
end
