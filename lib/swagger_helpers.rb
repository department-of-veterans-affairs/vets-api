# frozen_string_literal: true

module SwaggerHelpers
  module_function

  def add_to_required(block, fields)
    block.key(:required, Array(block.data[:required]) + Array(fields))
  end
end
