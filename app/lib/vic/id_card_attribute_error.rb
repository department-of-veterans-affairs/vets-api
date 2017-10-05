# frozen_string_literal: true
require 'common/exceptions/base_error'

module VIC
  class IDCardAttributeError < Common::Exceptions::BaseError
    def initialize(options = {})
      @detail = options[:detail] || i18n_field(:detail, {})
      @code = options[:code] || i18n_field(:code, {})
      @status = options[:status] || i18n_field(:status, {})
    end

    def errors
      Array(Common::Exceptions::SerializableError.new(i18n_data.merge(detail: @detail, code: @code, status: @status)))
    end
  end
end
