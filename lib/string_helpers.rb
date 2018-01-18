# frozen_string_literal: true

module StringHelpers
  module_function

  def capitalize_only(str)
    str.slice(0, 1).capitalize + str.slice(1..-1)
  end
end
