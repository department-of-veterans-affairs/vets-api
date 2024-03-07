# frozen_string_literal: true

require 'common/exceptions/base_error'

module VIC
  class IDCardAttributeError < Common::Exceptions::BaseError
    VIC002 = { status: 403, code: 'VIC002', detail: 'No EDIPI or not found in VA Profile' }.freeze
    VIC010 = { status: 403, code: 'VIC010', detail: 'Could not verify Veteran status' }.freeze
    NOT_ELIGIBLE = {
      status: 403,
      detail: 'Not eligible for a Veteran ID Card'
    }.freeze

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
