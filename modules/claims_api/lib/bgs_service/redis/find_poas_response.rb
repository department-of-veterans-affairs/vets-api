# frozen_string_literal: true

module ClaimsApi
  class FindPOAsResponse
    attr_reader :response

    def initialize(response)
      @response = response
    end

    def cache?
      @response.is_a?(Array) && @response.size.positive?
    end
  end
end
