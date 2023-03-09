# frozen_string_literal: true

module Mobile
  module V0
    class ClinicSlotsSerializer
      include JSONAPI::Serializer

      set_id :id

      set_type :clinic_slot

      attribute :start_date, &:start
      attribute :end_date, &:end
    end
  end
end
