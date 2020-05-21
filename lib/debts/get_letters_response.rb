# frozen_string_literal: true

module Debts
  class GetLettersResponse
    def initialize(res)
      # modify response here
      @res = res
    end

    def to_json(*_args)
      @res.to_json
    end
  end
end
