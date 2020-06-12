# frozen_string_literal: true

module JsonSchema
  class MissingSchema < StandardError
    def initialize(missing_key, keys)
      @missing_key = missing_key
      @keys = keys
    end

    def message
      "schema <#{@missing_key.inspect}> not found." \
        " schemas: #{@keys.sort.inspect}"
    end
  end
end
