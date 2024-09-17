# frozen_string_literal: true

module Mobile
  module V0
    class ClinicSlotsSerializer
      include JSONAPI::Serializer

      set_id :id

      set_type :clinic_slot

      attribute :start_date, &:start
      attribute :end_date, &:end

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
