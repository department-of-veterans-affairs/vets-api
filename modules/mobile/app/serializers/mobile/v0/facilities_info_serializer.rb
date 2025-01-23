# frozen_string_literal: true

module Mobile
  module V0
    class FacilitiesInfoSerializer
      include JSONAPI::Serializer

      set_type :facilities_info
      attribute :facilities
    end
  end
end
