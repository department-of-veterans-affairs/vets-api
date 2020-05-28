# frozen_string_literal: true

require 'common/exceptions/base_error'
require 'common/exceptions/serializable_error'

module Common
  module Exceptions::Internal
    class NoQueryParamsAllowed < Common::Exceptions::BaseError
      def errors
        Array(Common::Exceptions::SerializableError.new(i18n_interpolated))
      end
    end
  end
end
