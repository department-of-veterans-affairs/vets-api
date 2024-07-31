# frozen_string_literal: true

module VAOS
  module V2
    class SlotsSerializer
      include JSONAPI::Serializer

      set_id :id

      attributes :start,
                 :end

      attribute :location_id do |object|
        object.dig(:location, :vha_facility_id)
      end

      attribute :clinic_ien do |object|
        object.dig(:clinic, :clinic_ien)
      end

      attribute :practitioner_name do |object|
        object.dig(:practitioner, :name)
      end
    end
  end
end
