# frozen_string_literal: true

module SwaggerHelpers
  module_function

  def add_to_required(block, fields)
    block.key(:required, Array(block.data[:required]) + Array(fields))
  end

  def convert_regex(regex)
    JsRegex.new(regex).source
  end
end
