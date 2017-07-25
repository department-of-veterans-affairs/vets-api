# frozen_string_literal: true
require 'common/models/form'

module Preneeds
  class Base
    extend ActiveModel::Naming
    include Virtus.model(nullify_blank: true)

    def as_json(options = {})
      super(options).deep_transform_keys { |key| key.camelize(:lower) }
    end

    protected

    def eoas_ssn
      "#{ssn[0..2]}-#{ssn[3..4]}-#{ssn[5..8]}"
    end
  end
end
