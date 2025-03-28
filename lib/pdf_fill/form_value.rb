# frozen_string_literal: true

module PdfFill
  class FormValue
    attr_reader :extras_value

    def initialize(value, extras_value)
      @value = value
      @extras_value = extras_value
    end

    delegate :to_s, to: :@value

    delegate :size, to: :@value
  end
end
