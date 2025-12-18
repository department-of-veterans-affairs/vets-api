# frozen_string_literal: true

module AskVAApi
  class ZipStateValidationResult
    attr_reader :error_code, :error_message, :valid

    def initialize(valid:, error_code: nil, error_message: nil)
      @valid = valid
      @error_code = error_code
      @error_message = error_message
    end

    def error?
      !valid
    end
  end
end
