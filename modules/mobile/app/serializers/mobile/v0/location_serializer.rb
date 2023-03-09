# frozen_string_literal: true

module Mobile
  module V0
    class LocationSerializer
      include JSONAPI::Serializer

      set_type :location
      attributes :name,
                 :address
    end
  end
end
