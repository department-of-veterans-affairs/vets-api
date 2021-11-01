# frozen_string_literal: true

module Mobile
  module V0
    class LocationSerializer
      include FastJsonapi::ObjectSerializer

      set_type :location
      attributes :name,
                 :address
    end
  end
end
