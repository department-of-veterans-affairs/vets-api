# frozen_string_literal: true

module PdfFill
  class FormValue
    attr_reader :extras_value

    def initialize(value, extras_value)
      @value = value
      @extras_value = extras_value
    end

    def to_s
      @value.to_s
    end

    def size
      @value.size
    end
  end
end
