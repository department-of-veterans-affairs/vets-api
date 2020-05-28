# frozen_string_literal: true

require 'common/exceptions/base_error'
require 'common/exceptions/serializeable_error'

module Common
  module Exceptions::Internal
    # Ambiguous Request - the parameters passed in could not determine what query to call
    class AmbiguousRequest < Common::Exceptions::BaseError
      def initialize(detail)
        @detail = detail
      end

      def errors
        Array(Common::Exceptions::SerializableError.new(i18n_data.merge(detail: @detail)))
      end
    end
  end
end
