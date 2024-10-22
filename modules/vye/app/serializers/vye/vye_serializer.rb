# frozen_string_literal: true

module Vye
  class VyeSerializer
    def initialize(resource)
      @resource = resource
    end

    def to_json(*)
      Oj.dump(serializable_hash, mode: :compat, time_format: :ruby)
    end
  end
end
