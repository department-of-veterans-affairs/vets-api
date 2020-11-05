# frozen_string_literal: true

module DMC
  class Response
    def initialize(res)
      @res = res
      validate_response_against_schema(@res)
    end

    def to_json(*_args)
      @res.to_json
    end
  end
end
