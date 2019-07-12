# frozen_string_literal: true

module ClaimsApi
  class JsonApiMissingAttribute < StandardError
    attr_accessor :code
    attr_accessor :details
    def initialize(details)
      @code = 422
      @details = details
    end

    def to_json_api
      errors = details.map { |detail| { status: 422, detail: detail[:message], source: detail[:fragment] } }
      { errors: errors }
    end
  end
end
