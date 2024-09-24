# frozen_string_literal: true

module Preneeds
  # Parent class for other Preneeds Burial form related models
  # Should not be initialized directly
  #
  class VirtusBase
    extend ActiveModel::Naming
    include Virtus.model(nullify_blank: true)

    # Override `as_json`
    #
    # @param options [Hash]
    # @see https://github.com/rails/rails/blob/49c613463b758a520a6162e702acc1158fc210ca/activesupport/lib/active_support/core_ext/object/json.rb#L46
    #
    def as_json(options = {})
      super(options).deep_transform_keys { |key| key.camelize(:lower) }
    end
  end
end
