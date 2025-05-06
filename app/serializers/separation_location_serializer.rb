# frozen_string_literal: true

class SeparationLocationSerializer
  def initialize(resource)
    @resource = resource
  end

  def to_json(*)
    Oj.dump(serializable_hash, mode: :compat, time_format: :ruby)
  end

  def serializable_hash
    {
      status: @resource.status,
      separation_locations: @resource.separation_locations
    }
  end
end
