# frozen_string_literal: true

require 'common/exceptions/base_error'

module MHVAC
  class AccountCreationError < Common::Exceptions::BaseError
    def initialize(options = {})
      @detail = options[:detail] || i18n_field(:detail, {})
    end

    def errors
      Array(Common::Exceptions::SerializableError.new(i18n_data.merge(detail: @detail)))
    end
  end
end
