# frozen_string_literal: true

module Common
  module Exceptions::Internal
    class NoQueryParamsAllowed < Common::Exceptions::BaseError
      def errors
        Array(Common::Exceptions::SerializableError.new(i18n_interpolated))
      end
    end
  end
end
