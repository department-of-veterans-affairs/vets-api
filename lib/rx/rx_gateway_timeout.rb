# frozen_string_literal: true

require 'common/exceptions/base_error'

module Rx
  class RxGatewayTimeout < Common::Exceptions::BaseError
    def errors
      Array(Common::Exceptions::SerializableError.new(i18n_data))
    end
  end
end
