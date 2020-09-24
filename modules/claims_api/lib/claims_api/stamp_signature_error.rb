# frozen_string_literal: true

module ClaimsApi
  class StampSignatureError < StandardError
    attr_accessor :detail

    def initialize(message: nil, detail: nil)
      super(message)
      @detail = detail
    end
  end
end
