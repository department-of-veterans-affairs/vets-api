# frozen_string_literal: true

module CheckIn
  module Facilities
    class FacilitiesDataSerializer
      include JSONAPI::Serializer

      set_id(&:id)

      attribute :name, :type, :classification, :timezone, :phone, :physicalAddress
    end
  end
end
