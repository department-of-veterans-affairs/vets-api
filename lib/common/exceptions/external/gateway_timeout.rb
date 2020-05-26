# frozen_string_literal: true

module Common
  module Exceptions::External
    class GatewayTimeout < Common::Exceptions::BaseError
      def errors
        Array(Common::Exceptions::SerializableError.new(i18n_data))
      end
    end
  end
end
