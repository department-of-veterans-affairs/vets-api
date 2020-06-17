# frozen_string_literal: true

module ClaimsApi
  class StampSignatureError < StandardError
    attr_accessor :code
    attr_accessor :detail

    def initialize(message: nil, detail: nil)
      message = message if message.present?
      super(message)
      @detail = detail
    end
  end
end
