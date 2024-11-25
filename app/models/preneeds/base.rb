# frozen_string_literal: true

require 'vets/model'

# Parent class for other Preneeds Burial form related models
# Should not be initialized directly
#
module Preneeds
  class Base
    include Vets::Model
    # Override `as_json`
    #
    # @param options [Hash]
    #
    # @see ActiveModel::Serializers::JSON
    #
    def as_json(options = {})
      super(options).deep_transform_keys { |key| key.camelize(:lower) }
    end
  end
end
