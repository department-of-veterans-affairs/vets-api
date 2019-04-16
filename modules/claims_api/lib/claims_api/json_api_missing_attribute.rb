# frozen_string_literal: true

module ClaimsApi
  class JsonApiMissingAttribute < StandardError
    attr_accessor :code
    attr_accessor :detail
    def initialize(detail)
      @code = 422
      @detail = detail
    end

    def to_json_api
      errors = detail.map { |m| { status: 422, detail: m } }
      { errors: errors }
    end
  end
end
